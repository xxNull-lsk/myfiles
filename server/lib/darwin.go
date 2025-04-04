//go:build darwin
// +build darwin

package lib

import (
	"os"
	"strings"
	"syscall"
	"time"
)

func GetFileCreateTime(fileInfo os.FileInfo) time.Time {
	stat := fileInfo.Sys().(*syscall.Stat_t)
	return time.Unix(stat.Birthtimespec.Sec, stat.Birthtimespec.Nsec)
}

func IsHideFile(fileInfo os.FileInfo) bool {
	return strings.HasPrefix(fileInfo.Name(), ".")
}
