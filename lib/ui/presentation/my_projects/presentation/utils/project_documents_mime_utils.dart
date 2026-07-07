/// File extension → short badge label for DMS rows.
String mimeLabelFromFileName(String fileName) {
  final parts = fileName.split('.');
  if (parts.length < 2) return 'FILE';
  final ext = parts.last.trim().toUpperCase();
  if (ext.isEmpty) return 'FILE';

  return switch (ext) {
    'PDF' => 'PDF',
    'DOC' || 'DOCX' => 'DOC',
    'XLS' || 'XLSX' || 'CSV' => 'XLS',
    'PPT' || 'PPTX' => 'PPT',
    'PNG' || 'JPG' || 'JPEG' || 'GIF' || 'WEBP' || 'SVG' => 'IMG',
    'ZIP' || 'RAR' || '7Z' => 'ZIP',
    'TXT' => 'TXT',
    'DWG' || 'DXF' => 'CAD',
    _ => ext.length > 5 ? ext.substring(0, 5) : ext,
  };
}
