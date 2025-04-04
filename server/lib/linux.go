//go:build linux
// +build linux

package lib

import (
	"os"
	"strings"
	"syscall"
	"time"
)

func TimespecToTime(ts syscall.Timespec) time.Time {
	return time.Unix(int64(ts.Sec), int64(ts.Nsec))
}

func GetFileCreateTime(fileInfo os.FileInfo) time.Time {
	return TimespecToTime(fileInfo.Sys().(*syscall.Stat_t).Ctim)
}

func IsHideFile(fileInfo os.FileInfo) bool {
	return strings.HasPrefix(fileInfo.Name(), ".")
}
