package lib

import (
	"archive/zip"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
)

func CreateZipForFile(srcFile, destFilename string, processRW *ProgressReaderWriter) {
	processRW.TotalFileCount = 1
	fw, err := os.Create(destFilename)
	if err != nil {
		processRW.ProgressError = err
		processRW.Finished = true
		log.Println("CreateZipForFile: Create failed!", destFilename, err)
		return
	}
	defer fw.Close()
	zipW := zip.NewWriter(fw)
	defer zipW.Close()

	src, err := os.Open(srcFile)
	if err != nil {
		processRW.ProgressError = err
		processRW.Finished = true
		log.Println("createTarGzForFile: Open failed!", srcFile, err)
		return
	}
	defer src.Close()
	processRW.reader = src
	stat, _ := src.Stat()
	processRW.TotalSize = uint64(stat.Size())

	fileHead, err := zip.FileInfoHeader(stat)
	if err != nil {
		processRW.ProgressError = err
		processRW.Finished = true
		log.Println("CreateZipForDir: FileInfoHeader failed!", err)
		return
	}
	fileHead.Name = filepath.Base(srcFile)
	zipFW, err := zipW.CreateHeader(fileHead)
	if err != nil {
		processRW.ProgressError = err
		processRW.Finished = true
		log.Println("CreateZipForFile: CreateHeader failed!", srcFile, err)
		return
	}
	processRW.writer = zipFW

	_, err = io.Copy(processRW, processRW)
	if err != nil {
		log.Println("CreateZipForFile: Copy failed!", err)
		processRW.ProgressError = err
		processRW.Finished = true
		return
	}
	processRW.FinishFileCount++
	processRW.Finished = true
}

func CreateZipForDir(srcDir, destFilename string, processRW *ProgressReaderWriter) {
	fw, err := os.Create(destFilename)
	if err != nil {
		log.Println("CreateZipForDir: Create failed!", err)
		processRW.ProgressError = err
		processRW.Finished = true
		return
	}
	defer fw.Close()

	zipW := zip.NewWriter(fw)
	defer zipW.Close()

	go CalcDir(srcDir, false, processRW)

	processRW.ProgressError = filepath.Walk(srcDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			log.Println("CreateZipForDir: Walk failed!", err)
			return err
		}

		parentPath := filepath.Dir(srcDir)
		if !strings.HasSuffix(parentPath, string(os.PathSeparator)) {
			parentPath += string(os.PathSeparator)
		}
		relPath := strings.TrimPrefix(path, parentPath)
		relPath = strings.ReplaceAll(relPath, "\\", "/")
		fileHead, err := zip.FileInfoHeader(info)
		if err != nil {
			log.Println("CreateZipForDir: FileInfoHeader failed!", err)
			return err
		}
		if info.IsDir() {
			relPath += "/"
		}
		fileHead.Name = relPath
		fileHead.Method = zip.Deflate
		zipFW, err := zipW.CreateHeader(fileHead)
		if err != nil {
			log.Println("CreateZipForDir: CreateHeader failed!", err)
			return err
		}

		if info.IsDir() {
			return nil
		}

		file, err := os.Open(path)
		if err != nil {
			log.Println("CreateZipForDir: Open failed!", err, path)
			return err
		}
		defer file.Close()
		processRW.reader = file
		processRW.writer = zipFW
		_, err = io.Copy(processRW, processRW)
		if err != nil {
			log.Println("CreateZipForDir: Copy failed!", err)
			return err
		}
		processRW.FinishFileCount++
		return nil
	})

	processRW.Finished = true
}
