package webserver

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/shirou/gopsutil/cpu"
	"github.com/shirou/gopsutil/disk"
	"github.com/shirou/gopsutil/host"
	"github.com/shirou/gopsutil/mem"
)

func (ws *WebServer) ReqGetSystemInformation() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 获取内存的信息
		memInfo, _ := mem.VirtualMemory()

		// 获取CPU的信息
		physicalCount, _ := cpu.Counts(false)
		logicalCount, _ := cpu.Counts(true)

		totalPercent, _ := cpu.Percent(3*time.Second, false)
		perPercents, _ := cpu.Percent(3*time.Second, true)
		cpuInfos, _ := cpu.Info()

		// 获取IO信息
		mapIOCounterStat, _ := disk.IOCounters()

		// 获取分区信息
		partitionsInfos, _ := disk.Partitions(false)
		partitionsUsage := make([]*disk.UsageStat, 0)
		for _, info := range partitionsInfos {
			usage, _ := disk.Usage(info.Mountpoint)
			partitionsUsage = append(partitionsUsage, usage)
		}

		// 获取开机时间
		timestamp, _ := host.BootTime()
		t := time.Unix(int64(timestamp), 0)

		// 获取操作系统内核信息
		kernel_version, _ := host.KernelVersion()
		KernelArch, _ := host.KernelArch()
		virtualizationSystem, virtualizationRole, _ := host.Virtualization()

		// 获取操作系统内核信息
		platform, family, version, _ := host.PlatformInformation()

		// 获取用户信息
		users, _ := host.Users()
		c.JSON(http.StatusOK, gin.H{
			"memory": memInfo,
			"cpu": gin.H{
				"physical_count": physicalCount,
				"logical_count":  logicalCount,
				"total_percent":  totalPercent,
				"per_percents":   perPercents,
				"info":           cpuInfos,
			},
			"io_counter": mapIOCounterStat,
			"partitions": partitionsUsage,
			"users":      users,
			"os": gin.H{
				"boot_time":             t.Local().Format("2006-01-02 15:04:05"),
				"platform":              platform,
				"family":                family,
				"version":               version,
				"kernel_version":        kernel_version,
				"kernel_arch":           KernelArch,
				"virtualization_system": virtualizationSystem,
				"virtualization_role":   virtualizationRole,
			},
		})
	}
}
