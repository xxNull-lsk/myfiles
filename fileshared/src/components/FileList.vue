<template>
    <div class="breadcrumb">
        <el-breadcrumb separator="/">
            <el-breadcrumb-item v-for="(item, index) in currentPathSegments" :key="index">
                <el-button link @click="gotoSubDir(index)" :disabled="index === currentPathSegments.length - 1">
                    <el-icon v-if="index === 0" size="18">
                        <HomeFilled />
                    </el-icon>
                    <span v-else class="breadcrumbItem">{{ item }}</span>
                </el-button>
            </el-breadcrumb-item>
        </el-breadcrumb>
    </div>

    <div>
        <el-table :data="fileList" stripe>
            <el-table-column label="文件名" sortable class-name="name-column">
                <template #default="{ row }">
                    <el-button link v-if="row.is_dir" @click="gotoDir(row.name)">
                        <el-icon>
                            <Folder />
                        </el-icon>
                        &nbsp;
                        <span>{{ row.name }}</span>
                    </el-button>
                    <el-button link v-else @click="handleDownload(row.name)">
                        <el-icon>
                            <Document />
                        </el-icon>
                        <span>{{ row.name }}</span>
                    </el-button>
                </template>
            </el-table-column>
            <el-table-column width="128" sortable label="文件大小" class-name="size-column">
                <template #default="{ row }">
                    <span v-if="row.is_dir == false">
                        {{ formatFileSize(row.size) }}
                    </span>
                </template>
            </el-table-column>
            <el-table-column prop="modified_at" width="172" label="最后修改时间" sortable
                class-name="modified-column"></el-table-column>
        </el-table>
    </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { Document, Folder, HomeFilled } from '@element-plus/icons-vue';
import { fetchFileList, downloadFile, setCurrentPath } from '../api.js';

// 定义文件列表的响应式变量
const fileList = ref([]);
const currentPath = ref('/');
const currentPathSegments = ref(['/']);

// 格式化文件大小的函数
const formatFileSize = (size) => {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    let unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
        size /= 1024;
        unitIndex++;
    }
    return `${size.toFixed(2)} ${units[unitIndex]}`;
};

// 定义获取文件列表的函数
const getFileList = async (path) => {
    if (!path){
        path = currentPath.value;
    }
    const result = await fetchFileList(path);
    if (result.code !== 0) {
        return;
    }
    fileList.value = result.data;
    setCurrentPath(path);
    currentPath.value = path;
    console.log(`getFileList path=${path} currentPath.value=${currentPath.value}`);
    if (path === "/") {
        currentPathSegments.value = ['/'];
    } else {
        currentPathSegments.value = currentPath.value.split('/');
    }
};

const gotoSubDir = (index) => {
    let path = '/';
    if (index !== 0) {
        path = currentPathSegments.value.slice(0, index + 1).join('/');
    }
    getFileList(path);
};

const gotoDir = (name) => {
    let path = "";
    if (currentPath.value[currentPath.value.length - 1] === "/") {
        path = currentPath.value + name;
    } else {
        path = currentPath.value + "/" + name;
    }
    getFileList(path);
};

const handleDownload = (name) => {
    let path = "";
    if (currentPath.value[currentPath.value.length - 1] === "/") {
        path = currentPath.value + name;
    } else {
        path = currentPath.value + "/" + name;
    }
    console.log(`handleDownload path=${path}`);
    downloadFile(path);
};

// 定义刷新方法
const refreshFileList = () => {
    getFileList();
};

// 在组件挂载时调用获取文件列表的函数
onMounted(() => {
    getFileList();
});

// 向外暴露刷新方法
defineExpose({
    refreshFileList
});
</script>

<style scoped>
.name-column {
    width: 80em;
    /* 让 name 列宽度根据内容自适应 */
}

.size-column,
.modified-column {
    width: 1em;
}

.breadcrumb {
    margin-left: 0.5em;
    height: 2em;
    display: flex;
    align-items: center;
    border-bottom: 1px solid #b5b5b5;
}

.breadcrumbItem {
    font-family: 'Courier New', Courier, monospace;
    font-size: 1.3em;
    display: flex;
    align-items: center;
}
</style>
