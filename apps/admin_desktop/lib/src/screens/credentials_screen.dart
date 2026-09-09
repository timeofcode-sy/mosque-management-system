import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';

/// بطاقاتُ الدخول — ✅ م.6.5، فوق `GET /admin/credentials`.
///
/// **وما تعرضه محصورٌ بالرتبة على الخادم**: المشرفُ يبلغ بطاقاتِ الطلاب وأولياء
/// الأمور ولا يبلغ بطاقاتِ الحسابات الإدارية. والحصرُ هناك لا هنا — الطلبُ يصل
/// الخادمَ كيفما بُنيت الواجهة.
///
/// و`password` يعود `null` **لمن بدّل كلمته بنفسه**: النسخةُ المقروءة تُمسح
/// حينها فلا يبقى لأحدٍ اطّلاعٌ على ما اختاره. وذلك يُقال في البطاقة صراحةً بدل
/// أن يُترك فراغاً يُقرأ عطلاً.
class CredentialsScreen extends StatefulWidget {
  const CredentialsScreen({super.key});

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  final _search = TextEditingController();

  Future<List<CredentialCard>>? _future;
  String? _role;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    final deps = AppScope.of(context);

    setState(() {
      _future = deps.admin.loadCredentials(
        role: _role,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بيانات الدخول'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) => _reload(),
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 20),
                      hintText: 'ابحث بالاسم ثم اضغط Enter',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _role,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'الفئة',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('الكل')),
                      DropdownMenuItem(value: 'student', child: Text('الطلاب')),
                      DropdownMenuItem(value: 'guardian', child: Text('أولياء الأمور')),
                      DropdownMenuItem(value: 'teacher', child: Text('الأساتذة')),
                    ],
                    onChanged: (value) {
                      _role = value;
                      _reload();
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<CredentialCard>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return EmptyState(
                    message: isOffline(snapshot.error!)
                        ? 'البطاقاتُ لا تُخزَّن على الجهاز — تحتاج اتصالاً.'
                        : messageFor(snapshot.error!),
                    icon: Icons.wifi_off_outlined,
                    onRetry: _reload,
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final cards = snapshot.data!;

                if (cards.isEmpty) {
                  return const EmptyState(
                    message: 'لا بطاقاتِ دخولٍ مطابقة.',
                    icon: Icons.key_outlined,
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360,
                    mainAxisExtent: 152,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, index) =>
                      _Card(card: cards[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.card});

  final CredentialCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.name,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!card.isActive)
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
              ],
            ),
            if (card.detail != null)
              Text(card.detail!, style: theme.textTheme.bodySmall),
            const Spacer(),
            SelectableText(
              card.username ?? 'بلا اسم دخول',
              style: theme.textTheme.bodyMedium,
            ),
            SelectableText(
              // الفراغُ يُفسَّر ولا يُترك: «بدّلها بنفسه» حالةٌ سليمة لا عطب.
              card.password ?? 'بدّل كلمتَه بنفسه — لا نسخةَ مقروءة',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: card.password == null
                    ? theme.colorScheme.onSurfaceVariant
                    : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: card.password == null
                    ? null
                    : () {
                        Clipboard.setData(
                          ClipboardData(
                            text: '${card.username ?? ''}\n${card.password}',
                          ),
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('نُسخت البطاقة.')),
                        );
                      },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('نسخ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
