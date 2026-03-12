/* This file is part of the Spring engine (GPL v2 or later), see LICENSE.html */

#include "System/Platform/CpuTopology.h"

#include <algorithm>
#include <limits>
#include <thread>

#include <sys/sysctl.h>


namespace cpu_topology {

static uint32_t MakeCpuMask(uint32_t cpuCount)
{
	cpuCount = std::clamp(cpuCount, 1u, 32u);

	if (cpuCount >= 32u)
		return 0xFFFFFFFFu;

	return ((1u << cpuCount) - 1u);
}

static uint32_t QuerySysctlUInt32(const char* name)
{
	uint32_t value = 0;
	size_t size = sizeof(value);

	if ((sysctlbyname(name, &value, &size, nullptr, 0) == 0) && (value > 0))
		return value;

	return 0;
}

static uint32_t QuerySysctlCacheSize(const char* name)
{
	uint64_t value = 0;
	size_t size = sizeof(value);

	if ((sysctlbyname(name, &value, &size, nullptr, 0) == 0) && (value > 0))
		return static_cast<uint32_t>(std::min<uint64_t>(value, std::numeric_limits<uint32_t>::max()));

	return 0;
}

ProcessorMasks GetProcessorMasks()
{
	uint32_t logicalCpuCount = QuerySysctlUInt32("hw.logicalcpu");

	if (logicalCpuCount == 0)
		logicalCpuCount = std::max(1u, static_cast<uint32_t>(std::thread::hardware_concurrency()));

	const uint32_t allCpuMask = MakeCpuMask(logicalCpuCount);

	ProcessorMasks processorMasks;
	processorMasks.performanceCoreMask = allCpuMask;
	processorMasks.efficiencyCoreMask = allCpuMask;
	processorMasks.hyperThreadLowMask = 0;
	processorMasks.hyperThreadHighMask = 0;

	return processorMasks;
}

ProcessorCaches GetProcessorCache()
{
	ProcessorCaches processorCaches;
	ProcessorGroupCaches cacheGroup;

	cacheGroup.groupMask = GetProcessorMasks().performanceCoreMask;
	cacheGroup.cacheSizes[0] = QuerySysctlCacheSize("hw.l1dcachesize");
	cacheGroup.cacheSizes[1] = QuerySysctlCacheSize("hw.l2cachesize");
	cacheGroup.cacheSizes[2] = QuerySysctlCacheSize("hw.l3cachesize");

	processorCaches.groupCaches.push_back(cacheGroup);

	return processorCaches;
}

ThreadPinPolicy GetThreadPinPolicy()
{
	return THREAD_PIN_POLICY_NONE;
}

} // namespace cpu_topology
