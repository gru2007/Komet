import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/models/chat.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/models/message.dart';
import 'package:gwid/models/profile.dart';
import 'package:gwid/models/chat_folder.dart';

class MessageHandler {
  final void Function(VoidCallback) setState;
  final BuildContext Function() getContext;
  final List<Chat> allChats;
  final Map<int, Contact> contacts;
  final List<ChatFolder> folders;
  final Set<int> onlineChats;
  final Set<int> typingChats;
  final Map<int, Timer> typingDecayTimers;
  final Function(int) setTypingForChat;
  final Function() filterChats;
  final Function() refreshChats;
  final Function(List<dynamic>?) sortFoldersByOrder;
  final Function() updateFolderTabController;
  final TabController folderTabController;
  final Function(Profile) setMyProfile;
  final Function(String) showTokenExpiredDialog;
  final bool Function(Chat) isSavedMessages;

  MessageHandler({
    required this.setState,
    required this.getContext,
    required this.allChats,
    required this.contacts,
    required this.folders,
    required this.onlineChats,
    required this.typingChats,
    required this.typingDecayTimers,
    required this.setTypingForChat,
    required this.filterChats,
    required this.refreshChats,
    required this.sortFoldersByOrder,
    required this.updateFolderTabController,
    required this.folderTabController,
    required this.setMyProfile,
    required this.showTokenExpiredDialog,
    required this.isSavedMessages,
  });

  StreamSubscription? listen() {
    return ApiService.instance.messages.listen((message) {
      final context = getContext();
      if (!context.mounted) return;

      if (message['type'] == 'invalid_token') {
        print('Получено событие недействительного токена, перенаправляем на вход');
        showTokenExpiredDialog(
          message['message'] ?? 'Токен авторизации недействителен',
        );
        return;
      }

      final opcode = message['opcode'];
      final cmd = message['cmd'];
      final payload = message['payload'];

      if (opcode == 19 && (cmd == 0x100 || cmd == 256) && payload != null) {
        _handleProfileUpdate(payload);
        return;
      }

      if (payload == null) return;
      final chatIdValue = payload['chatId'];
      final int? chatId = chatIdValue != null ? chatIdValue as int? : null;

      if (opcode == 272 ||
          opcode == 274 ||
          opcode == 48 ||
          opcode == 55 ||
          opcode == 135) {
      } else if (chatId == null) {
        return;
      }

      if (opcode == 129 && chatId != null) {
        setTypingForChat(chatId);
      } else if (opcode == 64) {
        _handleNewChat(payload);
      } else if (opcode == 128 && chatId != null) {
        _handleNewMessage(chatId, payload);
      } else if (opcode == 67 && chatId != null) {
        _handleEditedMessage(chatId, payload);
      } else if (opcode == 66 && chatId != null) {
        _handleDeletedMessages(chatId, payload);
      } else if (opcode == 132) {
        _handlePresenceUpdate(payload);
      } else if (opcode == 36) {
        _handleBlockedContacts(payload);
      } else if (opcode == 48) {
        _handleGroupCreatedOrUpdated(payload);
      } else if (opcode == 89) {
        _handleJoinGroup(payload, cmd);
      } else if (opcode == 55) {
        _handleChatUpdate(payload, cmd);
      } else if (opcode == 135) {
        _handleChatRemoved(payload);
      } else if (opcode == 272) {
        _handleFoldersUpdate(payload);
      } else if (opcode == 274) {
        _handleFolderCreatedOrUpdated(payload, cmd);
      } else if (opcode == 276) {
        _handleFolderDeleted(payload, cmd);
      }
    });
  }

  void _handleProfileUpdate(Map<String, dynamic> payload) {
    final profileData = payload['profile'];
    if (profileData != null) {
      print('🔄 ChatsScreen: Получен профиль из opcode 19, обновляем UI');
      Future.microtask(() {
        final context = getContext();
        if (context.mounted) {
          setMyProfile(Profile.fromJson(profileData));
        }
      });
    }
  }

  void _handleNewChat(Map<String, dynamic> payload) {
    if (payload['chat'] is! Map<String, dynamic>) return;
    final chatJson = payload['chat'] as Map<String, dynamic>;
    final newChat = Chat.fromJson(chatJson);

    ApiService.instance.updateChatInCacheFromJson(chatJson);

    final context = getContext();
    if (context.mounted) {
      setState(() {
        final existingIndex = allChats.indexWhere((chat) => chat.id == newChat.id);
        if (existingIndex != -1) {
          allChats[existingIndex] = newChat;
        } else {
          final savedIndex = allChats.indexWhere(isSavedMessages);
          final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
          allChats.insert(insertIndex, newChat);
        }
        filterChats();
      });
    }
  }

  void _handleNewMessage(int chatId, Map<String, dynamic> payload) {
    final newMessage = Message.fromJson(payload['message']);
    ApiService.instance.clearCacheForChat(chatId);

    final int chatIndex = allChats.indexWhere((chat) => chat.id == chatId);

    if (chatIndex != -1) {
      final oldChat = allChats[chatIndex];
      final updatedChat = oldChat.copyWith(
        lastMessage: newMessage,
        newMessages: newMessage.senderId != oldChat.ownerId
            ? oldChat.newMessages + 1
            : oldChat.newMessages,
      );

      setState(() {
        allChats.removeAt(chatIndex);
        _insertChatAtCorrectPosition(updatedChat);
        filterChats();
      });
    } else if (payload['chat'] is Map<String, dynamic>) {
      final chatJson = payload['chat'] as Map<String, dynamic>;
      final newChat = Chat.fromJson(chatJson);
      ApiService.instance.updateChatInCacheFromJson(chatJson);

      setState(() {
        final savedIndex = allChats.indexWhere(isSavedMessages);
        final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
        allChats.insert(insertIndex, newChat);
        filterChats();
      });
    }
  }

  void _handleEditedMessage(int chatId, Map<String, dynamic> payload) {
    final editedMessage = Message.fromJson(payload['message']);
    ApiService.instance.clearCacheForChat(chatId);

    final int chatIndex = allChats.indexWhere((chat) => chat.id == chatId);
    if (chatIndex != -1) {
      final oldChat = allChats[chatIndex];
      if (oldChat.lastMessage.id == editedMessage.id) {
        final updatedChat = oldChat.copyWith(lastMessage: editedMessage);
        setState(() {
          allChats.removeAt(chatIndex);
          _insertChatAtCorrectPosition(updatedChat);
          filterChats();
        });
      }
    }
  }

  void _handleDeletedMessages(int chatId, Map<String, dynamic> payload) {
    final deletedMessageIds = List<String>.from(payload['messageIds'] ?? []);
    ApiService.instance.clearCacheForChat(chatId);

    final int chatIndex = allChats.indexWhere((chat) => chat.id == chatId);
    if (chatIndex != -1) {
      final oldChat = allChats[chatIndex];
      if (deletedMessageIds.contains(oldChat.lastMessage.id)) {
        ApiService.instance.getChatsOnly(force: true).then((data) {
          final context = getContext();
          if (context.mounted) {
            final chats = data['chats'] as List<dynamic>;
            final filtered = chats
                .cast<Map<String, dynamic>>()
                .where((chat) => chat['id'] == chatId)
                .toList();
            final Map<String, dynamic>? updatedChatData =
                filtered.isNotEmpty ? filtered.first : null;
            if (updatedChatData != null) {
              final updatedChat = Chat.fromJson(updatedChatData);
              setState(() {
                allChats.removeAt(chatIndex);
                allChats.insert(0, updatedChat);
                filterChats();
              });
            }
          }
        });
      }
    }
  }

  void _handlePresenceUpdate(Map<String, dynamic> payload) {
    final bool isOnline = payload['online'] == true;
    final dynamic contactIdAny = payload['contactId'] ?? payload['userId'];

    if (contactIdAny != null) {
      final int? cid = contactIdAny is int
          ? contactIdAny
          : int.tryParse(contactIdAny.toString());
      if (cid != null) {
        final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final userPresence = {
          'seen': currentTime,
          'on': isOnline ? 'ON' : 'OFF',
        };
        ApiService.instance.updatePresenceData({cid.toString(): userPresence});

        for (final chat in allChats) {
          final otherId = chat.participantIds.firstWhere(
            (id) => id != chat.ownerId,
            orElse: () => chat.ownerId,
          );
          if (otherId == cid) {
            if (isOnline) {
              onlineChats.add(chat.id);
            } else {
              onlineChats.remove(chat.id);
            }
          }
        }
        final context = getContext();
        if (context.mounted) setState(() {});
        return;
      }
    }

    final dynamic cidAny = payload['chatId'];
    final int? chatIdFromPayload = cidAny is int
        ? cidAny
        : int.tryParse(cidAny?.toString() ?? '');
    if (chatIdFromPayload != null) {
      if (isOnline) {
        onlineChats.add(chatIdFromPayload);
      } else {
        onlineChats.remove(chatIdFromPayload);
      }
      final context = getContext();
      if (context.mounted) setState(() {});
    }
  }

  void _handleBlockedContacts(Map<String, dynamic> payload) {
    if (payload['contacts'] == null) return;
    final List<dynamic> blockedContactsJson = payload['contacts'] as List;
    final blockedContacts = blockedContactsJson
        .map((json) => Contact.fromJson(json))
        .toList();

    for (final blockedContact in blockedContacts) {
      contacts[blockedContact.id] = blockedContact;
      ApiService.instance.notifyContactUpdate(blockedContact);
    }

    final context = getContext();
    if (context.mounted) setState(() {});
  }

  void _handleGroupCreatedOrUpdated(Map<String, dynamic> payload) {
    final chatJson = payload['chat'] as Map<String, dynamic>?;
    final chatsJson = payload['chats'] as List<dynamic>?;

    Map<String, dynamic>? effectiveChatJson = chatJson;
    if (effectiveChatJson == null && chatsJson != null && chatsJson.isNotEmpty) {
      final first = chatsJson.first;
      if (first is Map<String, dynamic>) {
        effectiveChatJson = first;
      }
    }

    if (effectiveChatJson != null) {
      final newChat = Chat.fromJson(effectiveChatJson);
      ApiService.instance.updateChatInCacheFromJson(effectiveChatJson);
      final context = getContext();
      if (context.mounted) {
        setState(() {
          final existingIndex = allChats.indexWhere((chat) => chat.id == newChat.id);
          if (existingIndex != -1) {
            allChats[existingIndex] = newChat;
          } else {
            final savedIndex = allChats.indexWhere(isSavedMessages);
            final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
            allChats.insert(insertIndex, newChat);
          }
        });
        filterChats();
      }
    } else {
      refreshChats();
    }
  }

  void _handleJoinGroup(Map<String, dynamic> payload, int cmd) {
    if (cmd != 0x100 && cmd != 256) return;
    final chatJson = payload['chat'] as Map<String, dynamic>?;
    if (chatJson != null) {
      final chatType = chatJson['type'] as String?;
      if (chatType == 'CHAT') {
        final newChat = Chat.fromJson(chatJson);
        ApiService.instance.updateChatInCacheFromJson(chatJson);
        final context = getContext();
        if (context.mounted) {
          setState(() {
            final existingIndex = allChats.indexWhere((chat) => chat.id == newChat.id);
            if (existingIndex != -1) {
              allChats[existingIndex] = newChat;
            } else {
              final savedIndex = allChats.indexWhere(isSavedMessages);
              final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
              allChats.insert(insertIndex, newChat);
            }
            filterChats();
          });
        }
      }
    }
  }

  void _handleChatUpdate(Map<String, dynamic> payload, int cmd) {
    if (cmd != 0x100 && cmd != 256) return;
    final chatJson = payload['chat'] as Map<String, dynamic>?;
    if (chatJson != null) {
      final updatedChat = Chat.fromJson(chatJson);
      ApiService.instance.updateChatInCacheFromJson(chatJson);
      final context = getContext();
      if (context.mounted) {
          setState(() {
            final existingIndex = allChats.indexWhere((chat) => chat.id == updatedChat.id);
            if (existingIndex != -1) {
              allChats[existingIndex] = updatedChat;
            } else {
              final savedIndex = allChats.indexWhere(isSavedMessages);
              final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
              allChats.insert(insertIndex, updatedChat);
            }
            filterChats();
          });
      }
    }
  }

  void _handleChatRemoved(Map<String, dynamic> payload) {
    if (payload['chat'] is! Map<String, dynamic>) return;
    final removedChat = payload['chat'] as Map<String, dynamic>;
    final int? removedChatId = removedChat['id'] as int?;
    final String? status = removedChat['status'] as String?;

    if (removedChatId != null && status == 'REMOVED') {
      final context = getContext();
      if (context.mounted) {
        setState(() {
          allChats.removeWhere((chat) => chat.id == removedChatId);
        });
      }
    }
  }

  void _handleFoldersUpdate(Map<String, dynamic> payload) {
    if (payload['folders'] == null && payload['foldersOrder'] == null) {
      refreshChats();
      return;
    }

    try {
      final foldersJson = payload['folders'] as List<dynamic>?;
      if (foldersJson != null) {
        final newFolders = foldersJson.map((json) {
          final jsonMap = json is Map<String, dynamic>
              ? json
              : Map<String, dynamic>.from(json as Map);
          return ChatFolder.fromJson(jsonMap);
        }).toList();

        final context = getContext();
        if (context.mounted) {
          setState(() {
            folders.clear();
            folders.addAll(newFolders);
            final foldersOrder = payload['foldersOrder'] as List<dynamic>?;
            sortFoldersByOrder(foldersOrder);
          });
          updateFolderTabController();
          filterChats();
        }
      }
    } catch (e) {
      print('Ошибка обработки папок из opcode 272: $e');
    }
  }

  void _handleFolderCreatedOrUpdated(Map<String, dynamic> payload, int cmd) {
    if (cmd != 0x100 && cmd != 256) return;
    try {
      final folderJson = payload['folder'] as Map<String, dynamic>?;
      if (folderJson != null) {
        final updatedFolder = ChatFolder.fromJson(folderJson);
        final folderId = updatedFolder.id;

        final context = getContext();
        if (context.mounted) {
          final existingIndex = folders.indexWhere((f) => f.id == folderId);
          final isNewFolder = existingIndex == -1;

          setState(() {
            if (existingIndex != -1) {
              folders[existingIndex] = updatedFolder;
            } else {
              folders.add(updatedFolder);
            }
            final foldersOrder = payload['foldersOrder'] as List<dynamic>?;
            sortFoldersByOrder(foldersOrder);
          });

          updateFolderTabController();
          filterChats();

          if (isNewFolder) {
            final newFolderIndex = folders.indexWhere((f) => f.id == folderId);
            if (newFolderIndex != -1) {
              final targetIndex = newFolderIndex + 1;
              if (folderTabController.length > targetIndex) {
                folderTabController.animateTo(targetIndex);
              }
            }
          }
        }
      }
    } catch (e) {
      print('Ошибка обработки созданной/обновленной папки из opcode 274: $e');
    }
  }

  void _handleFolderDeleted(Map<String, dynamic> payload, int cmd) {
    if (cmd != 0x100 && cmd != 256) return;
    try {
      final foldersOrder = payload['foldersOrder'] as List<dynamic>?;
      final context = getContext();
      if (foldersOrder != null && context.mounted) {
        final currentIndex = folderTabController.index;

        setState(() {
          final orderedIds = foldersOrder.map((id) => id.toString()).toList();
          folders.removeWhere((folder) => !orderedIds.contains(folder.id));
          sortFoldersByOrder(foldersOrder);
        });

        updateFolderTabController();
        filterChats();

        if (currentIndex >= folderTabController.length) {
          folderTabController.animateTo(0);
        } else if (currentIndex > 0) {
          folderTabController.animateTo(
            currentIndex < folderTabController.length ? currentIndex : 0,
          );
        }

        ApiService.instance.requestFolderSync();
      }
    } catch (e) {
      print('Ошибка обработки удаления папки из opcode 276: $e');
    }
  }

  void _insertChatAtCorrectPosition(Chat chat) {
    if (isSavedMessages(chat)) {
      if (chat.id == 0) {
        allChats.insert(0, chat);
      } else {
        final savedIndex = allChats.indexWhere(
          (c) => isSavedMessages(c) && c.id == 0,
        );
        final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
        allChats.insert(insertIndex, chat);
      }
    } else {
      final savedIndex = allChats.indexWhere(isSavedMessages);
      final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
      allChats.insert(insertIndex, chat);
    }
  }
}

