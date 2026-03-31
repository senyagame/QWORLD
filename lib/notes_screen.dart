import 'package:flutter/material.dart';
import 'dart:async';
import 'main.dart'; // Импорт для перевода и настроек темы

class Note {
  final String id;
  String title;
  String content;
  final DateTime date;

  Note({required this.id, required this.title, required this.content, required this.date});

// В будущем здесь можно добавить методы для работы с JSON (Shared Preferences)
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  // Список заметок теперь хранится локально в состоянии виджета
  static List<Note> _localNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  // Имитация загрузки из локального хранилища
  void _loadNotes() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _openNoteEditor({Note? note}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FullScreenNoteEditor(
          note: note,
          onSave: (title, content) {
            final trimmedTitle = title.trim();
            final trimmedContent = content.trim();

            if (trimmedTitle.isEmpty && trimmedContent.isEmpty && note == null) {
              return; // Не сохраняем пустую новую заметку
            }

            setState(() {
              if (note == null) {
                // Добавление новой заметки
                _localNotes.insert(
                  0,
                  Note(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: trimmedTitle,
                    content: trimmedContent,
                    date: DateTime.now(),
                  ),
                );
              } else {
                // Обновление существующей
                note.title = trimmedTitle;
                note.content = trimmedContent;
                // Перемещаем обновленную заметку наверх (опционально)
                _localNotes.remove(note);
                _localNotes.insert(0, note);
              }
            });
          },
        ),
      ),
    );
  }

  void _showActionMenu(int index) {
    final isRu = localeNotifier.value.languageCode == 'ru';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                title: Text(isRu ? "Редактировать" : "Edit"),
                onTap: () {
                  Navigator.pop(context);
                  _openNoteEditor(note: _localNotes[index]);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text(isRu ? "Удалить" : "Delete"),
                onTap: () {
                  setState(() {
                    _localNotes.removeAt(index);
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRu = localeNotifier.value.languageCode == 'ru';

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(
            isRu ? "Заметки" : "Notes",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _localNotes.isEmpty
          ? _buildEmptyState(isRu)
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: _localNotes.length,
        itemBuilder: (context, index) {
          final note = _localNotes[index];
          return GestureDetector(
            onTap: () => _openNoteEditor(note: note),
            onLongPress: () => _showActionMenu(index),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: isDark ? null : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.isNotEmpty ? note.title : (isRu ? "Без названия" : "Untitled"),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: note.title.isEmpty ? Colors.grey : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      note.content,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${note.date.day}.${note.date.month}.${note.date.year}",
                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () => _openNoteEditor(),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(bool isRu) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_alt_outlined, size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
              isRu ? "Нет заметок" : "No notes yet",
              style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600)
          ),
          const SizedBox(height: 8),
          Text(
              isRu ? "Нажмите +, чтобы создать первую" : "Tap + to create your first note",
              style: TextStyle(fontSize: 14, color: Colors.grey.withOpacity(0.7))
          ),
        ],
      ),
    );
  }
}

class FullScreenNoteEditor extends StatefulWidget {
  final Note? note;
  final Function(String, String) onSave;

  const FullScreenNoteEditor({super.key, this.note, required this.onSave});

  @override
  State<FullScreenNoteEditor> createState() => _FullScreenNoteEditorState();
}

class _FullScreenNoteEditorState extends State<FullScreenNoteEditor> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? "");
    _contentController = TextEditingController(text: widget.note?.content ?? "");
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _handleSave() {
    widget.onSave(_titleController.text, _contentController.text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isRu = localeNotifier.value.languageCode == 'ru';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _handleSave,
              child: Text(
                  isRu ? "Готово" : "Done",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.blueAccent)
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                autofocus: widget.note == null,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: isRu ? "Заголовок" : "Title",
                  hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                  border: InputBorder.none,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 18, height: 1.5),
                  decoration: InputDecoration(
                    hintText: isRu ? "Начните писать..." : "Start writing...",
                    hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}