import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase.dart';

class DataExportService {
  static Future<void> exportMyData(BuildContext context) async {
    final uid = supabase.auth.currentUser?.id;
    final userEmail = supabase.auth.currentUser?.email ?? 'Not provided';
    if (uid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not signed in')));
      }
      return;
    }

    try {
      // 1. Fetch Profile
      Map<String, dynamic>? profile;
      try {
        profile = await supabase.from('profiles').select().eq('id', uid).maybeSingle();
      } catch (e) {
        debugPrint('Export Profile Error: $e');
      }

      // 2. Fetch Posts
      List<Map<String, dynamic>> posts = [];
      try {
        final res = await supabase.from('posts').select().eq('author_id', uid).order('created_at', ascending: false);
        posts = List<Map<String, dynamic>>.from(res);
      } catch (e) {
        debugPrint('Export Posts Error: $e');
      }

      // 3. Fetch Essays
      List<Map<String, dynamic>> essays = [];
      try {
        final res = await supabase.from('essays').select().eq('author_id', uid).order('created_at', ascending: false);
        essays = List<Map<String, dynamic>>.from(res);
      } catch (e) {
        debugPrint('Export Essays Error: $e');
      }

      // 4. Fetch Comments
      List<Map<String, dynamic>> comments = [];
      try {
        final res = await supabase.from('comments').select().eq('user_id', uid).order('created_at', ascending: false);
        comments = List<Map<String, dynamic>>.from(res);
      } catch (e) {
        debugPrint('Export Comments Error: $e');
      }

      // 5. Fetch Events
      List<Map<String, dynamic>> events = [];
      try {
        final res = await supabase.from('events').select().eq('organizer_id', uid).order('created_at', ascending: false);
        events = List<Map<String, dynamic>>.from(res);
      } catch (e) {
        debugPrint('Export Events Error: $e');
      }

      // Build PDF Document
      final pdf = pw.Document();
      final goldColor = PdfColor.fromHex('#D4AF37');
      final darkHeaderColor = PdfColor.fromHex('#1A1020');
      final df = DateFormat('MMM dd, yyyy · HH:mm');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context ctx) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              padding: const pw.EdgeInsets.only(bottom: 10),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(children: [
                    pw.Text('IJWI', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: goldColor)),
                    pw.SizedBox(width: 8),
                    pw.Text('|  USER DATA STATEMENT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkHeaderColor)),
                  ]),
                  pw.Text('Exported: ${df.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                ],
              ),
            );
          },
          footer: (pw.Context ctx) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 20),
              padding: const pw.EdgeInsets.only(top: 10),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 1)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Ijwi Privacy Data Export · Strictly Confidential', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            );
          },
          build: (pw.Context ctx) {
            return [
              // ── 1. Profile Summary ─────────────────────────────────
              pw.Header(level: 0, text: 'Account Profile Summary'),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: goldColor, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(children: [
                      pw.Expanded(child: pw.Text('Voice Name: ${profile?['voice_name'] ?? 'Not set'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
                      pw.Expanded(child: pw.Text('Real Name: ${profile?['real_name'] ?? 'Not set'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
                    ]),
                    pw.SizedBox(height: 6),
                    pw.Row(children: [
                      pw.Expanded(child: pw.Text('Email: $userEmail', style: const pw.TextStyle(fontSize: 11))),
                      pw.Expanded(child: pw.Text('Revealed Identity: ${profile?['is_revealed'] == true ? 'Yes' : 'No'}', style: const pw.TextStyle(fontSize: 11))),
                    ]),
                    if (profile?['bio'] != null && profile!['bio'].toString().isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text('Bio: ${profile['bio']}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // ── 2. Posts & Sparks ──────────────────────────────────
              pw.Header(level: 0, text: 'Published Posts & Sparks (${posts.length})'),
              if (posts.isEmpty)
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text('No posts found.', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)))
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Type', 'Title / Content Snippet', 'Healed', 'Comments', 'Date'],
                  data: posts.map((p) {
                    final title = (p['title'] as String?)?.trim();
                    final body = (p['body'] as String?)?.trim() ?? '';
                    final type = (p['content_type'] ?? 'story').toString().toUpperCase();
                    final display = (title != null && title.isNotEmpty) ? title : (body.length > 50 ? '${body.substring(0, 50)}...' : body);
                    final dateStr = p['created_at'] != null ? df.format(DateTime.tryParse(p['created_at'].toString()) ?? DateTime.now()) : '';
                    return [
                      type,
                      display.isEmpty ? '(No text content)' : display,
                      (p['reaction_healed'] ?? 0).toString(),
                      (p['comment_count'] ?? 0).toString(),
                      dateStr,
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                  headerDecoration: pw.BoxDecoration(color: darkHeaderColor),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellPadding: const pw.EdgeInsets.all(6),
                ),
              pw.SizedBox(height: 20),

              // ── 3. Published Essays ─────────────────────────────────
              pw.Header(level: 0, text: 'Published Essays (${essays.length})'),
              if (essays.isEmpty)
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text('No essays published.', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)))
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Title', 'Subtitle', 'Read Time', 'Date'],
                  data: essays.map((e) {
                    final title = e['title'] ?? 'Untitled';
                    final sub = e['subtitle'] ?? '-';
                    final readTime = e['read_time'] ?? '3 min';
                    final dateStr = e['created_at'] != null ? df.format(DateTime.tryParse(e['created_at'].toString()) ?? DateTime.now()) : '';
                    return [title, sub, readTime, dateStr];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                  headerDecoration: pw.BoxDecoration(color: darkHeaderColor),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellPadding: const pw.EdgeInsets.all(6),
                ),
              pw.SizedBox(height: 20),

              // ── 4. Comments ───────────────────────────────────────
              pw.Header(level: 0, text: 'Activity & Comments (${comments.length})'),
              if (comments.isEmpty)
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text('No comments found.', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)))
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Comment Content', 'Date'],
                  data: comments.take(30).map((c) {
                    final content = (c['content'] ?? '').toString();
                    final dateStr = c['created_at'] != null ? df.format(DateTime.tryParse(c['created_at'].toString()) ?? DateTime.now()) : '';
                    return [content.length > 80 ? '${content.substring(0, 80)}...' : content, dateStr];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                  headerDecoration: pw.BoxDecoration(color: darkHeaderColor),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellPadding: const pw.EdgeInsets.all(6),
                ),
              pw.SizedBox(height: 20),

              // ── 5. Organized Events ─────────────────────────────────
              pw.Header(level: 0, text: 'Organized Events (${events.length})'),
              if (events.isEmpty)
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text('No events organized.', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)))
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Event Title', 'Location', 'Price', 'Date'],
                  data: events.map((ev) {
                    final title = ev['title'] ?? 'Untitled Event';
                    final loc = ev['location'] ?? 'Online';
                    final price = (ev['ticket_price'] != null && ev['ticket_price'] > 0) ? '\$${ev['ticket_price']}' : 'Free';
                    final dateStr = ev['event_date'] != null ? df.format(DateTime.tryParse(ev['event_date'].toString()) ?? DateTime.now()) : '';
                    return [title, loc, price, dateStr];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                  headerDecoration: pw.BoxDecoration(color: darkHeaderColor),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellPadding: const pw.EdgeInsets.all(6),
                ),
            ];
          },
        ),
      );

      // Save PDF to file
      final pdfBytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ijwi_user_data_export_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(pdfBytes);

      // Share / Download PDF
      if (context.mounted) {
        final box = context.findRenderObject() as RenderBox?;
        final origin = (box != null && box.hasSize) ? (box.localToGlobal(Offset.zero) & box.size) : null;

        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf', name: 'ijwi_user_data_export.pdf')],
          subject: 'My Ijwi Data Statement (PDF)',
          text: 'Here is your exported Ijwi account data statement in PDF format.',
          sharePositionOrigin: origin,
        );
      }
    } catch (e) {
      debugPrint('Export PDF Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export PDF statement: ${e.toString()}')));
      }
    }
  }
}
