/* This file is part of the Spring engine (GPL v2 or later), see LICENSE.html */

#include "System/Platform/Threading.h"

#include "System/Log/ILog.h"

#include <functional>
#include <memory>


namespace Threading {

void SetupCurrentThreadControls(std::shared_ptr<ThreadControls>& threadCtls)
{
	if (threadCtls.get() != nullptr) {
		LOG_L(L_WARNING, "[%s] thread already has ThreadControls installed", __func__);
	}

	threadCtls.reset(new Threading::ThreadControls());
	threadCtls->handle = GetCurrentThread();
	threadCtls->thread_id = 0;
	threadCtls->running.store(true);
}

void ThreadStart(
	std::function<void()> taskFunc,
	std::shared_ptr<ThreadControls>* threadCtls,
	ThreadControls* tempCtls
) {
	SetupCurrentThreadControls(localThreadControls);

	if (threadCtls != nullptr)
		*threadCtls = localThreadControls;

	{
		std::lock_guard<spring::mutex> lock(tempCtls->mutSuspend);
		tempCtls->condInitialized.notify_all();
	}

	taskFunc();

	if (localThreadControls != nullptr) {
		std::lock_guard<spring::mutex> lock(localThreadControls->mutSuspend);
		localThreadControls->running.store(false);
	}
}

SuspendResult ThreadControls::Suspend()
{
	LOG_L(L_WARNING, "[ThreadControls::%s] thread suspension is not implemented on macOS", __func__);
	return Threading::THREADERR_MISC;
}

SuspendResult ThreadControls::Resume()
{
	return Threading::THREADERR_NONE;
}

} // namespace Threading
