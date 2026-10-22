"""Raster grid, terrain derivatives, rasterization and polygonization."""
from __future__ import annotations

import io
import zipfile
from dataclasses import dataclass

import numpy as np
import shapely
from scipy import ndimage, signal
from shapely.geometry import MultiPolygon, Polygon, box

from . import geometry as G


@dataclass(frozen=True)
class Grid:
    """Cell (i=column, j=row) centre = (x0 + i*cell, z0 + j*cell). Rows run +z (south)."""
    x0: float
    z0: float
    cell: float
    nx: int
    nz: int

    @property
    def shape(self):
        return (self.nz, self.nx)

    def xs(self):
        return self.x0 + np.arange(self.nx) * self.cell

    def zs(self):
        return self.z0 + np.arange(self.nz) * self.cell

    def ij(self, x, z):
        return (int(round((x - self.x0) / self.cell)), int(round((z - self.z0) / self.cell)))

    def inside(self, i, j):
        return 0 <= i < self.nx and 0 <= j < self.nz

    def xz(self, i, j):
        return (self.x0 + i * self.cell, self.z0 + j * self.cell)

    def bounds(self):
        h = self.cell / 2
        return (self.x0 - h, self.z0 - h, self.x0 + (self.nx - 1) * self.cell + h,
                self.z0 + (self.nz - 1) * self.cell + h)

    def sub(self, xmin, zmin, xmax, zmax):
        """Sub-grid window (index slices) covering a world bbox, clipped."""
        i0 = max(0, int(np.floor((xmin - self.x0) / self.cell)))
        j0 = max(0, int(np.floor((zmin - self.z0) / self.cell)))
        i1 = min(self.nx, int(np.ceil((xmax - self.x0) / self.cell)) + 1)
        j1 = min(self.nz, int(np.ceil((zmax - self.z0) / self.cell)) + 1)
        g = Grid(self.x0 + i0 * self.cell, self.z0 + j0 * self.cell, self.cell, i1 - i0, j1 - j0)
        return g, (slice(j0, j1), slice(i0, i1))


def gaussian(arr, sigma_m, cell):
    return ndimage.gaussian_filter(arr.astype(np.float64), sigma=sigma_m / cell, mode="nearest")


def slope_aspect(h, cell):
    """Slope (deg) and downslope aspect bearing (deg) from central differences."""
    dz_row, dx_col = np.gradient(h, cell)  # d/dz (rows), d/dx (cols)
    grad = np.hypot(dx_col, dz_row)
    slope = np.degrees(np.arctan(grad))
    # downslope vector = -grad; bearing of (dx,dz) = atan2(dx, -dz)
    aspect = np.degrees(np.arctan2(-dx_col, dz_row)) % 360.0
    aspect[grad < 1e-6] = np.nan
    return slope, aspect, grad


def disk_kernel(radius_m, cell):
    r = int(round(radius_m / cell))
    y, x = np.mgrid[-r:r + 1, -r:r + 1]
    return (x * x + y * y <= r * r).astype(np.float64)


def disk_mean(arr, valid, radius_m, cell):
    """Normalized-convolution mean within a disk (edge cells use available data only)."""
    k = disk_kernel(radius_m, cell)
    a = np.where(valid, arr, 0.0)
    num = signal.fftconvolve(a, k, mode="same")
    den = signal.fftconvolve(valid.astype(np.float64), k, mode="same")
    with np.errstate(invalid="ignore", divide="ignore"):
        m = num / den
    m[den < 0.5] = np.nan
    return m


def disk_minmax(arr, radius_m, cell):
    k = disk_kernel(radius_m, cell).astype(bool)
    return (ndimage.minimum_filter(arr, footprint=k, mode="nearest"),
            ndimage.maximum_filter(arr, footprint=k, mode="nearest"))


def bilinear(grid: Grid, arr, x, z):
    fx = (np.asarray(x, dtype=float) - grid.x0) / grid.cell
    fz = (np.asarray(z, dtype=float) - grid.z0) / grid.cell
    return ndimage.map_coordinates(arr, [np.atleast_1d(fz), np.atleast_1d(fx)], order=1,
                                   mode="nearest")


def rasterize(grid: Grid, geom) -> np.ndarray:
    """Cells whose centre lies inside (or on) the polygonal geometry."""
    m = np.zeros(grid.shape, dtype=bool)
    if geom is None or geom.is_empty:
        return m
    xmin, zmin, xmax, zmax = geom.bounds
    sg, sl = grid.sub(xmin, zmin, xmax, zmax)
    if sg.nx <= 0 or sg.nz <= 0:
        return m
    X, Z = np.meshgrid(sg.xs(), sg.zs())
    shapely.prepare(geom)
    m[sl] = shapely.intersects_xy(geom, X, Z)
    return m


def mask_to_polygon(grid: Grid, mask: np.ndarray):
    """Exact union of cell squares (row runs) → polygonal geometry on the grid."""
    boxes = []
    h = grid.cell / 2
    for j in np.nonzero(mask.any(axis=1))[0]:
        row = mask[j]
        d = np.diff(np.concatenate([[0], row.view(np.int8), [0]]))
        starts = np.nonzero(d == 1)[0]
        ends = np.nonzero(d == -1)[0]
        z = grid.z0 + j * grid.cell
        for a, b in zip(starts, ends):
            boxes.append(box(grid.x0 + a * grid.cell - h, z - h, grid.x0 + (b - 1) * grid.cell + h, z + h))
    if not boxes:
        return Polygon()
    u = shapely.union_all(boxes, grid_size=G.GRID)
    return G.unsnap(G.polygonal(u))


def label(mask, eight=True):
    st = np.ones((3, 3), bool) if eight else None
    return ndimage.label(mask, structure=st)


def write_npz(path, arrays: dict) -> None:
    """Deterministic npz (fixed zip timestamps, sorted names)."""
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for name in sorted(arrays):
            b = io.BytesIO()
            np.lib.format.write_array(b, np.ascontiguousarray(arrays[name]), allow_pickle=False)
            zi = zipfile.ZipInfo(name + ".npy", date_time=(1980, 1, 1, 0, 0, 0))
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.external_attr = 0o644 << 16
            zf.writestr(zi, b.getvalue())
    with open(path, "wb") as f:
        f.write(buf.getvalue())
