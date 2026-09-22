import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

class ChatHistoryDrawer extends StatelessWidget {
  final bool isDark;
  final LocaleNotifier loc;
  final List<dynamic> sessions;
  final bool isLoadingSessions;
  final String? sessionsError;
  final String searchQuery;
  final TextEditingController searchController;
  final String? currentSessionId;
  final VoidCallback onRetry;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSelectSession;
  final ValueChanged<String> onDeleteSession;

  const ChatHistoryDrawer({
    super.key,
    required this.isDark,
    required this.loc,
    required this.sessions,
    required this.isLoadingSessions,
    required this.sessionsError,
    required this.searchQuery,
    required this.searchController,
    required this.currentSessionId,
    required this.onRetry,
    required this.onSearchChanged,
    required this.onSelectSession,
    required this.onDeleteSession,
  });

  @override
  Widget build(BuildContext context) {
    final filteredSessions = searchQuery.trim().isEmpty
        ? sessions
        : sessions.where((s) {
            final title = (s['title'] ?? '').toString().toLowerCase();
            final snippet = (s['lastSnippet'] ?? '').toString().toLowerCase();
            final q = searchQuery.trim().toLowerCase();
            return title.contains(q) || snippet.contains(q);
          }).toList();

    return Drawer(
      backgroundColor: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        loc.translate('chat.chatHistory'),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: searchController,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? AppColors.darkAccent : AppColors.lightPrimary),
                  ),
                ),
                onChanged: onSearchChanged,
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            // Session List
            Expanded(
              child: isLoadingSessions
                  ? Center(
                      child: CircularProgressIndicator(
                        color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                      ),
                    )
                  : sessionsError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_off_rounded,
                                  size: 28,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Couldn\'t load conversations',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: onRetry,
                                  child: Text(
                                    'Retry',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filteredSessions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              searchQuery.isNotEmpty ? 'No sessions found' : 'No previous conversations',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          itemCount: filteredSessions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final session = filteredSessions[index];
                            final sessionId = (session['id'] ?? '').toString();
                            final title = (session['title'] ?? 'Legal Conversation').toString();
                            final lastSnippet = (session['lastSnippet'] ?? '').toString();
                            final count = session['messageCount'] ?? 0;
                            final isSelected = currentSessionId == sessionId;

                            return InkWell(
                              onTap: () => onSelectSession(sessionId),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.12)
                                      : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 16,
                                      color: isSelected
                                          ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                            ),
                                          ),
                                          if (lastSnippet.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              lastSnippet,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                                fontSize: 11,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  loc.translate('chat.turnsCount', {'count': count.toString()}),
                                                  style: GoogleFonts.inter(
                                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                        color: isDark ? AppColors.darkError : AppColors.lightError,
                                      ),
                                      tooltip: 'Delete session',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => onDeleteSession(sessionId),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
