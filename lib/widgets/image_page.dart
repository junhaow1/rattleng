/// A widget to build the common image based pages.
//
// Time-stamp: <Friday 2024-11-01 10:19:56 +1100 Graham Williams>
//
/// Copyright (C) 2024, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://www.gnu.org/licenses/gpl-3.0.en.html
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://www.gnu.org/licenses/>.
///
/// Authors: Graham Williams, Yixiang Yin

library;

import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';

import 'package:rattle/constants/sunken_box_decoration.dart';
import 'package:rattle/constants/temp_dir.dart';
import 'package:rattle/utils/debug_text.dart';
import 'package:rattle/utils/select_file.dart';
import 'package:rattle/utils/show_image_dialog.dart';
import 'package:rattle/utils/show_ok.dart';
import 'package:rattle/utils/word_wrap.dart';
import 'package:rattle/widgets/delayed_tooltip.dart';

class ImagePage extends StatelessWidget {
  final String title;
  final String path;
  final bool svgImage;

  const ImagePage({
    super.key,
    required this.title,
    required this.path,
    this.svgImage = true,
  });

  /// Load the image bytes from the specified file path.
  ///
  /// This method attempts to read the image file as bytes. It waits for the
  /// file to exist, retrying up to 5 times with a 1-second delay between each
  /// retry.  If the file does not exist after the retries, it returns `null`.
  ///
  /// Returns a [Future] that completes with the image bytes as a [Uint8List] if
  /// the file exists, or `null` if the file does not exist.

  Future<Uint8List?> _loadImageBytes() async {
    var imageFile = File(path);

    // Wait until the file exists, but limit the waiting period to avoid an infinite loop.
    int retries = 5;
    while (!await imageFile.exists() && retries > 0) {
      await Future.delayed(const Duration(seconds: 1));
      retries--;
    }

    // If the file doesn't exist, return null.
    if (!await imageFile.exists()) {
      return null;
    }

    // Read file as bytes
    return await imageFile.readAsBytes();
  }

  /// Convert the file [svgPath] return [Future] image bytes in PNG format.
  ///
  /// Throws an [Exception] if the conversion fails.

  Future<ByteData> _svgToImageBytes(String svgPath) async {
    final svgString = await File(svgPath).readAsString();

    final pictureInfo = await vg.loadPicture(
      SvgStringLoader(svgString),
      null,
    );

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final size = pictureInfo.size;

    canvas.scale(1.0, 1.0);

    pictureInfo.picture.toImage(size.width.toInt(), size.height.toInt());

    final image = await pictureInfo.picture
        .toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Failed to convert SVG to image bytes');
    }

    return byteData;
  }

  /// Export the SVG file [svgPath] into a PDF file [pdfPath].

  Future<void> _exportToPdf(String svgPath, String pdfPath) async {
    final pngBytes = await _svgToImageBytes(svgPath);

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(
              pw.MemoryImage(pngBytes.buffer.asUint8List()),
            ),
          );
        },
      ),
    );

    final file = File(pdfPath);
    await file.writeAsBytes(await pdf.save());
  }

  /// Export the SVG file [svgPath] into a PNG file [pngPath].

  Future<void> _exportToPng(String svgPath, String pngPath) async {
    final pngBytes = await _svgToImageBytes(svgPath);

    final file = File(pngPath);
    await file.writeAsBytes(pngBytes.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    debugText('  IMAGE', path);

    // Clear the image cache
    imageCache.clear();
    imageCache.clearLiveImages();

    return FutureBuilder<Uint8List?>(
      future: _loadImageBytes(),
      builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
        var bytes = snapshot.data;
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (bytes == null || bytes.isEmpty) {
          return const Center(
            child: Text(
              'Image not available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          );
        } else {
          return Container(
            decoration: sunkenBoxDecoration,
            width: double.infinity,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    // 20240726 gjw Ensure the Save button is aligned at the top.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 20240726 gjw Remove the Flexible for now. Perhaps avoid
                      // long text in the Image Page for now. Save button was
                      // not getting pushed all the way to the right after
                      // adding Flexible.
                      //
                      // 20240725 gjw Introduce the Flexible wrapper to avoid the markdown
                      // text overflowing to the elevarted Export
                      // button.
                      MarkdownBody(
                        data: wordWrap(title),
                        selectable: true,
                        onTapLink: (text, href, title) {
                          final Uri url = Uri.parse(href ?? '');
                          launchUrl(url);
                        },
                      ),
                      const Spacer(),
                      DelayedTooltip(
                        message: '''

                        Enlarge: Tap here to view the plot enlarged to the
                        maximimum size within the app.

                        ''',
                        child: IconButton(
                          icon: const Icon(
                            Icons.zoom_out_map,
                            color: Colors.blue,
                          ),
                          onPressed: () {
                            showImageDialog(context, bytes);
                          },
                        ),
                      ),
                      DelayedTooltip(
                        message: '''

                        Open: Tap here to open the plot in a separate window to
                        the Rattle app itself. This allows you to retain a view
                        of the plot while you navigate through other plots and
                        analyses. If you choose the external app to be Inkscape,
                        for example, then you can edit the details of the plot.

                        ''',
                        child: IconButton(
                          icon: const Icon(
                            Icons.open_in_new,
                            color: Colors.blue,
                          ),
                          onPressed: () {
                            // Generate a unique file name for the new file in the
                            // temporary directory.

                            String fileName =
                                'plot_${Random().nextInt(10000)}.svg';
                            File tempFile = File('$tempDir/$fileName');

                            // Copy the original file to the temporary file.
                            File(path).copy(tempFile.path);

                            // Pop out a window to display the plot separate
                            // to the Rattle app.

                            Platform.isWindows
                                ? Process.run(
                                    'start',
                                    [tempFile.path],
                                    runInShell: true,
                                  )
                                : Process.run('open', [tempFile.path]);
                          },
                        ),
                      ),
                      DelayedTooltip(
                        message: '''

                        Save: Tap here to save the plot in your preferred format
                        (SVG, PDF, or PNG). You can directly choose your desired
                        format by replacing the default SVG filename extension
                        with either PDF or PNG. The file is saved to your local
                        storage. Perfect for including in reports or keeping for
                        future reference.

                        ''',
                        child: IconButton(
                          icon: const Icon(
                            Icons.save,
                            color: Colors.blue,
                          ),
                          onPressed: () async {
                            String fileName = path.split('/').last;
                            String? pathToSave = await selectFile(
                              defaultFileName: fileName,
                              allowedExtensions: ['svg', 'pdf', 'png'],
                            );
                            if (pathToSave != null) {
                              String extension =
                                  pathToSave.split('.').last.toLowerCase();
                              if (extension == 'svg') {
                                await File(path).copy(pathToSave);
                              } else if (extension == 'pdf') {
                                await _exportToPdf(path, pathToSave);
                              } else if (extension == 'png') {
                                await _exportToPng(path, pathToSave);
                              } else {
                                // If the user selected an unsupported file
                                // extension show an error dialog.
                                showOk(
                                  title: 'Error',
                                  context: context,
                                  content: //const Text(
                                      '''

                                      An unsupported filename extension was
                                      provided: .$extension.  Please try again
                                      and select a filename with one of the
                                      supported extensions: .svg, .pdf, or .png.

                                      ''',
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // The max available width from LayoutBuilder.

                      final maxWidth = constraints.maxWidth;

                      // Apply a bounded height to avoid infinite height error.

                      final double maxHeight =
                          MediaQuery.of(context).size.height * 0.6;

                      return SizedBox(
                        height: maxHeight,
                        width: maxWidth,
                        child: InteractiveViewer(
                          maxScale: 5,
                          alignment: Alignment.topCenter,
                          child: svgImage
                              ? SvgPicture.memory(
                                  bytes,
                                  fit: BoxFit.scaleDown,
                                )
                              : Image.memory(bytes),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
