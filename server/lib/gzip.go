package lib

import (
	"archive/tar"
	"compress/gzip"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type ProgressReaderWriter struct {
	Pid             string
	StartTime       time.Time
	SrcFilename     string
	DestFilename    string
	ExtName         string
	FinishWriteSize uint64
	FinishReadSize  uint64
	TotalSize       uint64
	FinishFileCount uint64
	TotalFileCount  uint64
	reader          io.Reader
	writer          io.Writer
	ProgressError   error
	Finished        bool
	DownloadCount   int
}

func (pw *ProgressReaderWriter) UpdateFileInfo(dirCount uint64, fileCount uint64, fileSize int64) {
	pw.TotalSize += uint64(fileSize)
	pw.TotalFileCount += fileCount
}

func (pw *ProgressReaderWriter) Read(data []byte) (int, error) {
	if pw.ProgressError != nil {
		return 0, pw.ProgressError
	}
	n, err := pw.reader.Read(data)
	if err != nil && err != io.EOF {
		log.Println("progressReaderWriter: Read failed!", err)
		pw.ProgressError = err
		return n, err
	}
	if n == 0 {
		return n, io.EOF
	}
	pw.FinishReadSize += uint64(n)
	return n, nil
}

func (pw *ProgressReaderWriter) Write(data []byte) (int, error) {
	if pw.ProgressError != nil {
		return 0, pw.ProgressError
	}
	n, err := pw.writer.Write(data)
	if err != nil {
		log.Println("progressReaderWriter: Write failed!", err)
		pw.ProgressError = err
		return n, err
	}
	pw.FinishWriteSize += uint64(n)
	return n, nil
}

func (pw *ProgressReaderWriter) WriteStderr(s string) {
	fmt.Fprint(pw, s)
	log.Println("progressReaderWriter: WriteStderr", s)
}

func CreateTarGzForFile(srcFile, destFilename string, processRW *ProgressReaderWriter) {
	processRW.TotalFileCount = 1
	fw, err := os.Create(destFilename)
	if err != nil {
		processRW.ProgressError = err
		processRW.Finished = true
		log.Println("CreateTarGzForFile: Create failed!", destFilename, err)
		return
	}
	defer fw.Close()

	// 设置gzip writer
	gzw := gzip.NewWriter(fw)
	defer gzw.Close()

	file, err := os.Open(srcFile)
	if err != nil {
		processRW.ProgressError = err
		processRW.Finished = true
		log.Println("CreateTarGzForFile: Open failed!", srcFile, err)
		return
	}
	defer file.Close()
	processRW.reader = file
	stat, _ := file.Stat()
	processRW.TotalSize = uint64(stat.Size())

	hdr, err := tar.FileInfoHeader(stat, "")
	if err != nil {
		fmt.Println(err)
	}
	tw := tar.NewWriter(gzw)
	defer tw.Close()

	err = tw.WriteHeader(hdr) //写入头文件信息
	if err != nil {
		processRW.ProgressError = err
		processRW.Finished = true
		log.Println("CreateTarGzForFile: WriteHeader failed!", srcFile, err)
		return
	}

	processRW.writer = tw
	_, err = io.Copy(processRW, processRW)
	if err != nil {
		log.Println("CreateTarGzForFile: Copy failed!", err)
		processRW.ProgressError = err
		processRW.Finished = true
		return
	}
	processRW.FinishFileCount++
	processRW.Finished = true
}

func CreateTarGzForDir(srcDir, destFilename string, processRW *ProgressReaderWriter) {
	fw, err := os.Create(destFilename)
	if err != nil {
		log.Println("CreateTarGzForDir: Create failed!", err)
		processRW.ProgressError = err
		processRW.Finished = true
		return
	}
	defer fw.Close()

	gzw := gzip.NewWriter(fw)
	defer gzw.Close()

	go CalcDir(srcDir, false, processRW)

	tw := tar.NewWriter(gzw)
	defer tw.Close()

	processRW.ProgressError = filepath.Walk(srcDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			log.Println("CreateTarGzForDir: Walk failed!", err)
			return err
		}

		header, err := tar.FileInfoHeader(info, info.Name())
		if err != nil {
			log.Println("CreateTarGzForDir: FileInfoHeader failed!", err)
			return err
		}

		parentPath := filepath.Dir(srcDir)
		if !strings.HasSuffix(parentPath, string(os.PathSeparator)) {
			parentPath += string(os.PathSeparator)
		}
		relPath := strings.TrimPrefix(path, parentPath)
		header.Name = strings.ReplaceAll(relPath, "\\", "/")

		err = tw.WriteHeader(header)
		if err != nil {
			log.Println("CreateTarGzForDir: WriteHeader failed!", err)
			return err
		}

		if info.IsDir() {
			return nil
		}

		file, err := os.Open(path)
		if err != nil {
			log.Println("CreateTarGzForDir: Open failed!", err, path)
			return err
		}
		defer file.Close()
		processRW.reader = file
		processRW.writer = tw
		_, err = io.Copy(processRW, processRW)
		if err != nil {
			log.Println("CreateTarGzForDir: Copy failed!", err)
			return err
		}
		processRW.FinishFileCount++
		return nil
	})

	processRW.Finished = true
}
