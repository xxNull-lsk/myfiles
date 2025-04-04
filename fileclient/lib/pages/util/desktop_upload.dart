import 'package:file_picker/file_picker.dart';
import 'package:fileclient/global.dart';

import '../../backend/dio_util.dart';
import '../../backend/task_manager.dart';

Future<bool> onUpload(
    int pageID,
    String url,
    Map<String, dynamic> params,
    HttpProgressCallback onSendProgress,
    HttpSucceedCallback onSucceed,
    HttpFailedCallback onFailed) async {
    final FilePickerResult? file = await FilePicker.platform.pickFiles(
      dialogTitle: "选择要上传的文件",
      lockParentWindow: true,
    );
  if (file == null) {
    return false;
  }
  TransTaskItem task = TransTaskItem(
    pageID: pageID,
    taskType: TaskType.upload,
    localFilePath: file.files.first.path!,
    remoteFilePath: url,
    params: params,
  );
  return Global.taskManager!.addTask(task);
}
