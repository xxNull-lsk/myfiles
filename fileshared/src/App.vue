<template>
  <div id="top-head" :class="{ 'header-notitle': isLeftTitleVisible, 'header-withtitle': !isLeftTitleVisible }">
    <span class="top-title" :style="{ display: isLeftTitleVisible ? 'none' : 'flex' }">{{ sharedInfo.creator }}创建与{{
      sharedInfo.create_at }}的共享：{{ sharedInfo.name }}</span>
    <div class="toolbar">
      <el-button v-if="CODE !== null" type="primary" @click="refreshFileList" :icon="Refresh" circle />
    </div>
  </div>
  <div class="wrapper">
    <div class="left-title" :style="{ display: isLeftTitleVisible ? 'flex' : 'none' }">
      <div class="shared-name">共享名称：{{ sharedInfo.name }}</div>
      <div class="creator-info">创建者：{{ sharedInfo.creator }}</div>
      <div class="create-time">创建时间：{{ sharedInfo.create_at }}</div>
      <div class="version-info">
        {{ versionInfo.name }} {{ versionInfo.version }}<br>
        {{ shortCommit }}<br>
        {{ versionInfo.time }}</div>
    </div>
    <div class="right-content">
      <div class="main">
        <el-upload v-if="sharedInfo.can_upload" ref="uploadRef" class="elUpload" drag :action="uploadUrl"
          :multiple="true" :show-file-list="true" :on-success="handleUploadSuccess"
          :on-error="handleUploadError"><el-icon class="el-icon--upload">
            <UploadFilled />
          </el-icon>
          <div class="el-upload__text">
            拖放文件到此处 或 <em>点击上传</em>
          </div>
        </el-upload>
        <div class="login" v-if="CODE === null">
          <el-card style="width: 24em;">
            <template #header>
              <div class="card-header">
                <span>共享码</span>
              </div>
            </template>
            <el-input v-model="code" placeholder="请输入共享码" />
            <div class="loginButtons">
              <el-button type="primary" @click="checkCode(true)">访问</el-button>
            </div>
          </el-card>
        </div>
        <!--显示共享的基本信息-->
        <FileList v-else ref="fileListRef" />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ElNotification } from 'element-plus'
import { Refresh, UploadFilled } from '@element-plus/icons-vue'
import { ref, onMounted, onBeforeUnmount, watch, h, computed } from 'vue';
import FileList from './components/FileList.vue';
import { fetchSharedInfo, BASE_API_URL, setParams, setBaseApiUrl, setCode } from './api.js';
import { currentPath, getUploadUrl, getServerInfo } from './api.js';
// 使用 reactive 来创建响应式对象
import { reactive } from 'vue';

const sharedInfo = reactive({});
const fileListRef = ref(null);
const code = ref('');
const CODE = ref(null);
const uploadUrl = ref('');
const uploadRef = ref(null);
const versionInfo = ref({});

const shortCommit = computed(() => {
  return versionInfo.value.commit ? versionInfo.value.commit.slice(0, 6) : '';
});

// 刷新文件列表
const refreshFileList = () => {
  if (fileListRef.value) {
    fileListRef.value.refreshFileList();
  }
};

const checkCode = (showNotification) => {
  console.log(`code.value=${code.value} BASE_API_URL=${BASE_API_URL}`);
  fetchSharedInfo(code.value).then((res) => {
    if (res.code != 0) {
      if (res.data) {
        Object.assign(sharedInfo, res.data);
      }
      // 弹出错误信息
      if (showNotification) {
        ElNotification({
          title: '共享码错误',
          message: h('i', { style: 'color: red' }, res.message),
          type: 'error',
        });
      }
      return;
    }
    CODE.value = code.value;
    setCode(CODE.value);
    Object.assign(sharedInfo, res.data);
    // 获取上传地址
    uploadUrl.value = getUploadUrl();
  });
};
// 定义一个 ref 来控制 left-title 的显示与隐藏
const isLeftTitleVisible = ref(true);

// 监听窗口大小变化的函数
const handleResize = () => {
  if (window.innerWidth < window.innerHeight) {
    isLeftTitleVisible.value = false;
  } else {
    isLeftTitleVisible.value = true;
  }
};
onBeforeUnmount(() => {
  // 移除窗口大小变化监听，避免内存泄漏
  window.removeEventListener('resize', handleResize);
});
onMounted(() => {
  document.title = '文件共享';
  var params = "";
  handleResize();
  window.addEventListener('resize', handleResize);
  // 获取 URL 参数
  const urlParams = new URLSearchParams(window.location.search);
  for (const [key, value] of urlParams.entries()) {
    if (key === 'code') {
      continue;
    }
    if (params != "") {
      params += "&";
    }
    params += key + "=" + value;
  }
  if (import.meta.env.DEV) {
    if (!params.includes("sid")) {
      if (params != "") {
        params += "&";
      }
      params += "sid=VpepGqViUKA3HUmA";
    }
    code.value = "Ct40mk";
    setBaseApiUrl('https://TEST_SERVER_URL:8773');
    console.log('当前是开发模式');
  } else {
    setBaseApiUrl(window.location.origin);
    console.log('当前是生产模式');
  }
  setParams(params);
  const paramCode = urlParams.get('code');
  if (paramCode) {
    code.value = paramCode;
  }
  checkCode(false);
  getServerInfo().then((result) => {
    if (result.code === 0) { // 假设成功返回的 code 是 0
      versionInfo.value = result.data;
    }
  });
});

const handleUploadSuccess = (response, file, fileList) => {
  console.log('上传成功', response);
  if (uploadRef.value) {
    uploadRef.value.clearFiles();
  }
  ElNotification({
    title: '上传成功',
    message: '文件已成功上传',
    type: 'success',
  });
  refreshFileList();
};

const handleUploadError = (error, file, fileList) => {
  console.error('上传失败', error);
  ElNotification({
    title: '错误',
    message: '文件上传失败',
    type: 'error',
  });
};

// 监听 currentPath 的变化
watch(currentPath, (newPath) => {
  if (CODE.value) {
    uploadUrl.value = getUploadUrl();
  }
});
</script>

<style scoped>
.wrapper {
  display: flex;
  height: 100vh;
}

.top-title {
  font-family: 'Courier New', Courier, monospace;
  font-weight: 800;
}

.header-withtitle {
  height: 3em;
  width: 100%;
  padding: 0.5em;
  margin: 0;
  background-color: #2196f3;
  color: white;
  display: flex;
  /* 新增 */
  align-items: center;
  /* 新增 */
  justify-content: space-between;
  /* 新增 */
}

.header-notitle {
  height: 3em;
  width: 100%;
  padding: 0.5em;
  margin: 0;
  background-color: #2196f3;
  color: white;
}

.toolbar {
  float: right;
  padding: 0.5em;
  padding-right: 1em;
  text-align: right;
}

.left-title {
  max-width: 10em;
  flex: 1;
  padding: 3em 0.5em;
  background-color: white;
  color: darkgray;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  justify-content: flex-start;
  box-shadow: 0.05em 0 1em rgba(33, 150, 243, 0.5);
}

.version-info {
  font-size: small;
  margin-top: auto;
}

.shared-name,
.creator-info,
.create-time {
  margin-bottom: 0.3em;
}

.right-content {
  flex: 3;
  display: flex;
  flex-direction: column;
}

.main {
  flex: 1;
  padding: 0 1em;
}

.title {
  font-family: 'Courier New', Courier, monospace;
  font-weight: 800;
}

.login {
  display: flex;
  background-color: white;
  justify-content: center;
  align-items: center;
  min-height: calc(100vh - 3em);
}

.loginButtons {
  display: flex;
  justify-content: center;
  margin-top: 1em;
}

.elUpload {
  margin: 0.5em;
}
</style>
