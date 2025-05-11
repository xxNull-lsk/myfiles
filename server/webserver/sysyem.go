package webserver

import (
	"bytes"
	"encoding/json"
	"fmt"
	"myfileserver/lib"
	"net/http"
	"os"
	"os/exec"
	"path"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	jsoniter "github.com/json-iterator/go"
	"github.com/shirou/gopsutil/cpu"
	"github.com/shirou/gopsutil/disk"
	"github.com/shirou/gopsutil/host"
	"github.com/shirou/gopsutil/mem"
	"github.com/shirou/gopsutil/net"
)

// TemperatureData 表示整个 JSON 数据的结构，键为设备名，值为 Device 结构体
type TemperatureData map[string]Device

// Device 表示单个设备的信息，包含适配器信息和传感器指标
type Device struct {
	Adapter string            `json:"Adapter"`
	Metrics map[string]Metric `json:",inline"`
}

// Metric 表示传感器的各项指标，键为指标名，值为对应的数值
type Metric map[string]float64

// GetCPUTemperatures 函数用于获取 CPU 各个温度传感器的温度
func GetCPUTemperatures() (float64, []float64, error) {
	// 检查是否为 Linux 系统
	if runtime.GOOS != "linux" {
		return 0, nil, fmt.Errorf("unsupported operating system")
	}

	// 通过运行程序获取温度信息，sensors -j 2>/dev/null
	cmd := exec.Command("/usr/bin/sensors", "-j")
	output, err := cmd.Output()
	if err != nil {
		return 0, nil, fmt.Errorf("failed to run sensors command: %v \n\n%v", err, string(output))
	}

	// 解析 JSON 数据
	var data map[string]interface{}
	err = json.Unmarshal(output, &data)
	if err != nil {
		return 0, nil, fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	coreTemp, ok := data["coretemp-isa-0000"].(map[string]interface{})
	if !ok {
		return 0, nil, fmt.Errorf("coretemp-isa-0000 not found")
	}

	packageID0, ok := coreTemp["Package id 0"].(map[string]interface{})
	if !ok {
		return 0, nil, fmt.Errorf("package id 0 not found")
	}

	temp1Input, ok := packageID0["temp1_input"].(float64)
	if !ok {
		return 0, nil, fmt.Errorf("temp1_input not found")
	}

	// 查找"Core N"的温度传感器
	var temperatures []float64
	for key, value := range coreTemp {
		if !strings.HasPrefix(key, "Core ") {
			continue
		}
		for k, v := range value.(map[string]interface{}) {
			if !strings.HasSuffix(k, "_input") {
				continue
			}
			if temp, ok := v.(float64); ok {
				temperatures = append(temperatures, temp)
			}
		}
	}

	return temp1Input, temperatures, nil
}

func (ws *WebServer) MontiorCpuInformation() {
	interval, _ := time.ParseDuration("900ms")
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()
	for range ticker.C {
		cpuStatus := CpuStatus{}
		cpuStatus.TotalPercent, _ = cpu.Percent(interval, false)
		cpuStatus.PerPercents, _ = cpu.Percent(interval, true)
		cpuStatus.Temperature, cpuStatus.PreTemperatures, _ = GetCPUTemperatures()
		ws.CpuStatus = append(ws.CpuStatus, CpuStateInfo{
			Time: time.Now(),
			Stat: cpuStatus,
		})
		if len(ws.CpuStatus) > 61 {
			ws.CpuStatus = ws.CpuStatus[1:]
		}
	}
}

func (ws *WebServer) MontiorNetInformation() {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()
	for range ticker.C {
		// 记录传输数据，以便后续计算网络上传和下载的速率
		netIOCountersStats, err := net.IOCounters(true)
		if err != nil {
			lib.Logger.Error("Failed to get network I/O counters:", err)
			return
		}
		ws.NetStates = append(ws.NetStates, NetStateInfo{
			Time: time.Now(),
			Stat: netIOCountersStats,
		})
		if len(ws.NetStates) > 61 {
			ws.NetStates = ws.NetStates[1:]
		}
	}
}

func (ws *WebServer) MontiorMemoryInformation() {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()
	for range ticker.C {
		memInfo, err := mem.VirtualMemory()
		if err != nil {
			lib.Logger.Error("Failed to get memory info:", err)
			continue
		}
		ws.MemoryStates = append(ws.MemoryStates, MemoryStateInfo{
			Time: time.Now(),
			Stat: *memInfo,
		})
		if len(ws.MemoryStates) > 61 {
			ws.MemoryStates = ws.MemoryStates[1:]
		}
	}
}

func (ws *WebServer) MontiorDiskInformation() {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()
	for range ticker.C {
		// 记录传输数据，以便后续计算网络上传和下载的速率
		diskIOCountersStats, err := disk.IOCounters()
		if err != nil {
			lib.Logger.Error("Failed to get disk I/O counters:", err)
			continue
		}
		ws.DiskStates = append(ws.DiskStates, DiskStateInfo{
			Time: time.Now(),
			Stat: diskIOCountersStats,
		})
		if len(ws.DiskStates) > 61 {
			ws.DiskStates = ws.DiskStates[1:]
		}
	}
}

type BlockBaseInfo struct {
	BlockDevices []BlockDevice `json:"blockdevices"`
}

type BlockDevice struct {
	Name        string         `json:"name"`
	Fstype      *string        `json:"fstype"`
	FsVer       *string        `json:"fsver"`
	Label       *string        `json:"label"`
	UUID        *string        `json:"uuid"`
	Fsavail     *int64         `json:"fsavail,omitempty"` // 可能是 null、整数或字符串，用 interface{} 处理
	Fsused      *string        `json:"fsuse%,omitempty"`
	Mountpoints []*string      `json:"mountpoints"`
	Children    *[]BlockDevice `json:"children,omitempty"`
	Size        int64          `json:"size,omitempty"`
}

func GetBlockDeviceSize(name string) int64 {
	fileContent, err := os.ReadFile("/sys/class/block/" + name + "/size")
	if err != nil {
		lib.Logger.Error("Failed to get disk size:", err, " name:", name)
		return 0
	}
	fileContent = bytes.TrimSpace(fileContent)
	size, err := strconv.ParseInt(string(fileContent), 10, 64)
	if err != nil {
		lib.Logger.Error("Failed to parse disk size:", err, " name:", name)
		return 0
	}
	return size
}

func (ws *WebServer) GetDiskInformation() gin.H {

	if runtime.GOOS != "linux" {
		return gin.H{}
	}
	blockStateInfo := make(map[string][]BlockStateInfo)
	for i := range len(ws.DiskStates) - 1 {
		curr := ws.DiskStates[i]
		next := ws.DiskStates[i+1]
		seconds := next.Time.Sub(curr.Time).Seconds()
		for j := range curr.Stat {
			currStat := curr.Stat[j]
			nextStat := next.Stat[j]
			blockStateInfo[currStat.Name] = append(blockStateInfo[currStat.Name], BlockStateInfo{
				Time: curr.Time,
				Stat: BlockStatus{
					ReadSpeed:  float64(nextStat.ReadBytes-currStat.ReadBytes) / seconds,
					WriteSpeed: float64(nextStat.WriteBytes-currStat.WriteBytes) / seconds,
				},
			})
		}
	}

	blockBaseInfo := BlockBaseInfo{}
	// 执行lsblk -ipJbf命令
	cmd := exec.Command("lsblk", "-ipJbf")
	output, err := cmd.Output()
	if err == nil {
		// 解析JSON格式的输出
		var json = jsoniter.ConfigCompatibleWithStandardLibrary
		err = json.Unmarshal(output, &blockBaseInfo)
		if err != nil {
			lib.Logger.Error("Error parsing lsblk output:", err, "\n\n", string(output))
		}
	} else {
		// 处理错误
		lib.Logger.Error("Error executing lsblk command:", err)
	}

	blocks := make(map[string]interface{})
	for i := range len(blockBaseInfo.BlockDevices) {
		info := &blockBaseInfo.BlockDevices[i]
		name := path.Base(info.Name)
		info.Size = GetBlockDeviceSize(name)
		if info.Children != nil {
			for j := range len(*info.Children) {
				child := &(*info.Children)[j]
				childName := path.Base(child.Name)
				child.Size = GetBlockDeviceSize(childName)
			}
		}

		blocks[name] = gin.H{
			"name":        name,
			"fstype":      info.Fstype,
			"fsver":       info.FsVer,
			"label":       info.Label,
			"uuid":        info.UUID,
			"fsavail":     info.Fsavail,
			"fsuse%":      info.Fsused,
			"size":        info.Size,
			"mountpoints": info.Mountpoints,
			"children":    info.Children,
			"state_info":  blockStateInfo[name],
		}
	}
	// 获取IO信息
	mapIOCounterStat, _ := disk.IOCounters()

	// 获取分区信息
	partitionsInfos, _ := disk.Partitions(false)
	partitionsUsage := make([]*disk.UsageStat, 0)
	for _, info := range partitionsInfos {
		usage, _ := disk.Usage(info.Mountpoint)
		partitionsUsage = append(partitionsUsage, usage)
	}
	return gin.H{
		"blocks":     blocks,
		"counters":   mapIOCounterStat,
		"partitions": partitionsUsage,
	}
}

func (ws *WebServer) GetNetInformation() gin.H {
	speedSend := make(map[string][]float64)
	speedRecv := make(map[string][]float64)
	for i := range len(ws.NetStates) - 1 {
		curr := ws.NetStates[i]
		next := ws.NetStates[i+1]
		seconds := next.Time.Sub(curr.Time).Seconds()
		for j := range curr.Stat {
			currStat := curr.Stat[j]
			nextStat := next.Stat[j]
			speedSend[currStat.Name] = append(speedSend[currStat.Name], float64(nextStat.BytesSent-currStat.BytesSent)/seconds)
			speedRecv[currStat.Name] = append(speedRecv[currStat.Name], float64(nextStat.BytesRecv-currStat.BytesRecv)/seconds)
		}
	}
	netInterfaces, _ := net.Interfaces()
	// 添加虚拟网卡标识
	interfaces := make(map[string]interface{})
	for _, info := range netInterfaces {
		if info.Name == "lo" {
			info.Flags = append(info.Flags, "virtual")
		} else if strings.HasPrefix(info.Name, "veth") ||
			strings.HasPrefix(info.Name, "tap") ||
			strings.HasPrefix(info.Name, "docker") ||
			strings.HasPrefix(info.Name, "br-") ||
			strings.HasPrefix(info.Name, "tun") ||
			strings.HasPrefix(info.Name, "virbr") {
			info.Flags = append(info.Flags, "virtual")
		}
		interfaces[info.Name] = gin.H{
			"index":        info.Index,
			"mtu":          info.MTU,
			"name":         info.Name,
			"hardwareaddr": info.HardwareAddr,
			"flags":        info.Flags,
			"addrs":        info.Addrs,
			"speed_send":   speedSend[info.Name],
			"speed_recv":   speedRecv[info.Name],
		}
	}

	netIOCountersStats, err := net.IOCounters(true)
	if err != nil {
		lib.Logger.Error("Failed to get network I/O counters:", err)
	}
	return gin.H{
		"interfaces": interfaces,
		"counters":   netIOCountersStats,
	}

}

func (ws *WebServer) getCpuInfo() gin.H {
	// 获取CPU的信息
	physicalCount, _ := cpu.Counts(false)
	logicalCount, _ := cpu.Counts(true)
	cpuInfos, _ := cpu.Info()
	return gin.H{
		"physical_count": physicalCount,
		"logical_count":  logicalCount,
		"status":         ws.CpuStatus,
		"info":           cpuInfos,
	}

}

func (ws *WebServer) ReqGetMemoryInformation() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "success",
			"data":    ws.MemoryStates,
		})
	}
}

func (ws *WebServer) ReqGetCpuInformation() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "success",
			"data":    ws.getCpuInfo(),
		})
	}
}

func (ws *WebServer) ReqGetDiskInformation() gin.HandlerFunc {
	return func(c *gin.Context) {
		blocks := ws.GetDiskInformation()
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "success",
			"data":    blocks,
		})
	}
}

func (ws *WebServer) ReqGetNetInformation() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "success",
			"data":    ws.GetNetInformation(),
		})
	}
}

func (ws *WebServer) ReqGetSystemInformation() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 获取内存的信息
		memInfo, _ := mem.VirtualMemory()

		// 获取开机时间
		timestamp, _ := host.BootTime()
		bootTime := time.Unix(int64(timestamp), 0)

		// 获取操作系统内核信息
		kernel_version, _ := host.KernelVersion()
		KernelArch, _ := host.KernelArch()
		virtualizationSystem, virtualizationRole, _ := host.Virtualization()

		// 获取操作系统内核信息
		platform, family, version, _ := host.PlatformInformation()

		// 获取用户信息
		users, _ := host.Users()
		c.JSON(http.StatusOK, gin.H{
			"memory":  memInfo,
			"cpu":     ws.getCpuInfo(),
			"network": ws.GetNetInformation(),
			"disk":    ws.GetDiskInformation(),
			"users":   users,
			"os": gin.H{
				"boot_time":             bootTime.Local().Format("2006-01-02 15:04:05"),
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
