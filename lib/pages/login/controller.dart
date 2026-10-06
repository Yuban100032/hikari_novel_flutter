import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/main.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/common/constants.dart';
import 'package:hikari_novel_flutter/router/route_path.dart';
import 'package:hikari_novel_flutter/service/api_service.dart';

import '../../common/database/database.dart';
import '../../models/resource.dart';
import '../../parser/parser.dart';
import '../../service/db_service.dart';
import '../../service/local_storage_service.dart';
import '../../service/browser_session.dart';

class LoginController extends GetxController {
  RxBool showLoading = true.obs;
  RxInt loadingProgress = 0.obs;
  final CookieManager cookieManager = CookieManager.instance(webViewEnvironment: webViewEnvironment);
  InAppWebViewController? inAppWebViewController;
  final GlobalKey webViewKey = GlobalKey();
  final InAppWebViewSettings settings = InAppWebViewSettings(isInspectable: kDebugMode, userAgent: kUserAgent["User-Agent"], javaScriptEnabled: true);
  RxString currentUrl = "".obs;

  Rx<PageState> pageState = PageState.success.obs;
  String errorMsg = "";
  bool _savingSession = false;

  String get url => "${ApiService.instance.wenku8Node.node}/login.php";

  @override
  void onInit() {
    super.onInit();
    cookieManager.deleteAllCookies();
  }

  Future<void> saveCookie(WebUri uri) async {
    showLoading.value = false;
    if (_savingSession) return;

    //存储cookie
    if (uri.host == Uri.parse(ApiService.instance.wenku8Node.node).host) {
      final getCookie = await cookieManager.getCookies(url: uri);

      bool hasCookie = ["jieqiUserInfo", "jieqiVisitInfo"].every(
        (keyword) => getCookie.any((cookieItem) => cookieItem.name == keyword),
      ); //getCookie.any((cookieItem) => cookieItem.name == "jieqiUserInfo");
      if (hasCookie) {
        if (_savingSession) return;
        _savingSession = true;
        // Include the verification cookies issued by this WebView, not just account cookies.
        final cookie = encodeBrowserSession(
          Uri.parse(ApiService.instance.wenku8Node.node),
          {for (final item in getCookie) item.name: item.value},
        );
        LocalStorageService.instance.setCookie(cookie);

        try {
          await ApiService.instance.initCookie();
          await _getUserInfo();
          await _refreshBookshelf();
        } catch (e) {
          LocalStorageService.instance.setCookie(null); //清空cookie
          ApiService.instance.deleteCookie();

          final controller = inAppWebViewController;
          if (controller != null) {
            inAppWebViewController = null;
            controller.dispose(); //销毁webview，停止加载网页
          }

          errorMsg = e.toString();
          pageState.value = PageState.error;

          return;
        } finally {
          _savingSession = false;
        }

        Get.offAllNamed(RoutePath.main);
      }
    }
  }

  Future<void> _getUserInfo() async {
    final data = await ApiService.instance.getUserInfo();
    switch (data) {
      case Success():
        LocalStorageService.instance.setUserInfo(Parser.getUserInfo(data.data));
      case Error():
        {
          throw data.error;
        }
    }
  }

  Future<void> _refreshBookshelf() async {
    await DBService.instance.deleteAllBookshelf();

    final futures = Iterable.generate(6, (index) async {
      await _insertAll(index);
    });
    await Future.wait(futures);
  }

  Future<void> _insertAll(int index) async {
    final result = await ApiService.instance.getBookshelf(classId: index);
    switch (result) {
      case Success():
        {
          final bookshelf = Parser.getBookshelf(result.data, index);
          if (bookshelf.list.isNotEmpty) {
            final insertData = bookshelf.list.map((e) {
              return BookshelfEntityData(aid: e.aid, bid: e.bid, url: e.url, title: e.title, img: e.img, classId: bookshelf.classId.toString());
            });
            await DBService.instance.insertAllBookshelf(insertData);
          }
        }
      case Error():
        {
          throw result.error;
        }
    }
  }
}
