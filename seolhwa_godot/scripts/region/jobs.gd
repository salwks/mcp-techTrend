# 작업 스레드 감싸기 — 렌더 자원(메시·MultiMesh·재질)을 만드는 짓기(식생 흩뿌리기·키트 짓기)가 쓴다.
# 헤드리스(더미 렌더러)는 RID 저장소가 스레드 안전하지 않아, 작업 스레드와 메인 스레드가 동시에 메시를 만들면
# "Initializing already initialized RID"·"multimesh is null"로 자원이 엉키고 끝낼 때 signal 11이 났다.
# 그래서 헤드리스(또는 --serialjobs)에서는 작업을 그 자리에서 메인 스레드로 돌리고, 끝난 가짜 번호를 돌려준다.
# 창 모드(Mobile/RD 렌더러)는 저장소가 스레드 안전이라 예전처럼 WorkerThreadPool을 쓴다.
extends RefCounted

const SYNC_BASE := 1 << 50   # 이 위 번호는 이미 끝난 동기 작업(WorkerThreadPool 번호는 여기까지 오지 않는다)
static var sync: bool = DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--serialjobs")
static var _n := 0

static func add(c: Callable, desc := "") -> int:
	if sync:
		c.call(); _n += 1
		return SYNC_BASE + _n
	return WorkerThreadPool.add_task(c, false, desc)

static func add_group(c: Callable, n: int, tasks := -1, desc := "") -> int:
	if sync:
		for i in n: c.call(i)
		_n += 1
		return SYNC_BASE + _n
	return WorkerThreadPool.add_group_task(c, n, tasks, true, desc)

static func done(id: int) -> bool:
	return id >= SYNC_BASE or WorkerThreadPool.is_task_completed(id)

static func wait(id: int) -> void:
	if id >= 0 and id < SYNC_BASE: WorkerThreadPool.wait_for_task_completion(id)

static func group_done(id: int) -> bool:
	return id >= SYNC_BASE or WorkerThreadPool.is_group_task_completed(id)

static func group_wait(id: int) -> void:
	if id >= 0 and id < SYNC_BASE: WorkerThreadPool.wait_for_group_task_completion(id)
