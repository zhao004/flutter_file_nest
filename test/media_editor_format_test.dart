import 'package:filenest/app/preview/media_editor_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  test('图片输出格式按扩展名推断，未知格式回退 PNG', () {
    expect(imageOutputFormatForName('a.JPG'), OutputFormat.jpg);
    expect(imageOutputFormatForName('a.jpeg'), OutputFormat.jpg);
    expect(imageOutputFormatForName('a.png'), OutputFormat.png);
    expect(imageOutputFormatForName('a.webp'), OutputFormat.png);
    expect(imageOutputFormatForName('noext'), OutputFormat.png);
    expect(imageCopyExtension(OutputFormat.jpg), 'jpg');
    expect(imageCopyExtension(OutputFormat.png), 'png');
  });

  test('副本名追加 _edited 并在重名时递增序号', () {
    expect(editedCopyName('photo.jpg', 'jpg', const []), 'photo_edited.jpg');
    expect(
      editedCopyName('photo.jpg', 'jpg', const ['photo_edited.jpg']),
      'photo_edited(2).jpg',
    );
    expect(
      editedCopyName('photo.jpg', 'jpg', const [
        'photo_edited.jpg',
        'photo_edited(2).JPG',
      ]),
      'photo_edited(3).jpg',
    );
  });

  test('视频副本扩展名固定 mp4，多段名与无扩展名也正确处理', () {
    expect(videoCopyExtension, 'mp4');
    expect(
      editedCopyName('clip.mp4', videoCopyExtension, const []),
      'clip_edited.mp4',
    );
    expect(
      editedCopyName('archive.tar.gz', 'png', const []),
      'archive.tar_edited.png',
    );
    expect(editedCopyName('.hidden', 'png', const []), '.hidden_edited.png');
  });
}
