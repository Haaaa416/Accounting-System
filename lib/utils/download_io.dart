/// 手機版暫時不支援匯出檔案
Future<bool> saveTextFile(String filename, String content,
    {String mime = 'text/plain'}) async {
  throw UnsupportedError('手機版暫時不支援匯出，請用網頁版');
}
