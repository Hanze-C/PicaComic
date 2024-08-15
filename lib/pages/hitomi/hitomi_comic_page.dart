import 'package:flutter/material.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/network/hitomi_network/hitomi_main_network.dart';
import 'package:pica_comic/network/hitomi_network/hitomi_models.dart';
import 'package:pica_comic/network/hitomi_network/image.dart';
import 'package:pica_comic/network/res.dart';
import 'package:pica_comic/pages/comic_page.dart';
import 'package:pica_comic/pages/hitomi/hitomi_search.dart';
import 'package:pica_comic/pages/reader/comic_reading_page.dart';
import 'package:pica_comic/pages/search_result_page.dart';
import 'package:pica_comic/tools/extensions.dart';
import 'package:pica_comic/tools/tags_translation.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/history.dart';
import 'package:pica_comic/foundation/local_favorites.dart';
import 'package:pica_comic/tools/translations.dart';

class HitomiComicPage extends BaseComicPage<HitomiComic> {
  const HitomiComicPage(this.comic, {super.key});

  HitomiComicPage.fromLink(String link, {super.key})
      : comic = HitomiComicBrief("", "", "", [], "", "", link, "");

  final HitomiComicBrief comic;

  @override
  String? get url => comic.link;

  @override
  void openFavoritePanel() {
    favoriteComic(FavoriteComicWidget(
      havePlatformFavorite: false,
      needLoadFolderData: false,
      target: comic.link,
      setFavorite: (b) {
        if (favorite != b) {
          favorite = b;
          update();
        }
      },
      selectFolderCallback: (folder, page) {
        LocalFavoritesManager().addComic(
            folder, FavoriteItem.fromHitomi(data!.toBrief(comic.link, cover)));
        showToast(message: "成功添加收藏".tl);
      },
    ));
  }

  @override
  String get cover => comic.cover;

  @override
  void download() => _downloadComic(data!, context, comic.cover, comic.link);

  @override
  EpsData? get eps => null;

  @override
  String? get introduction => null;

  @override
  Future<Res<HitomiComic>> loadData() async {
    if (comic.cover == "") {
      var id = RegExp(r"\d+(?=\.html)").firstMatch(comic.link)![0]!;
      var res = await HiNetwork().getComicInfoBrief(id);
      if (res.error) {
        return Res.fromErrorRes(res);
      } else {
        comic.cover = res.data.cover;
        comic.name = res.data.name;
        comic.tagList = res.data.tagList;
        comic.artist = res.data.artist;
        comic.lang = res.data.lang;
        comic.time = res.data.time;
        comic.type = res.data.type;
      }
    }
    return HiNetwork().getComicInfo(comic.link);
  }

  @override
  int? get pages => null;

  @override
  void read(History? history) async {
    history = await History.createIfNull(history, data!);
    App.globalTo(() => ComicReadingPage.hitomi(
      data!,
      comic.link,
      initialPage: history!.page,
    ));
  }

  @override
  Widget? recommendationBuilder(HitomiComic data) => SliverGrid(
        delegate: SliverChildBuilderDelegate(childCount: data.related.length,
            (context, i) {
          return HitomiComicTileDynamicLoading(data.related[i]);
        }),
        gridDelegate: SliverGridDelegateWithComics(),
      );

  @override
  String get tag => "Hitomi ComicPage ${comic.link}";

  @override
  Map<String, List<String>>? get tags => {
        "Artists".categoryTextDynamic: data!.artists ?? ["N/A"],
        "Groups".categoryTextDynamic: data!.group,
        "Categories".categoryTextDynamic: data!.type.toList(),
        "Time".categoryTextDynamic: data!.time.toList(),
        "Languages".categoryTextDynamic: data!.lang.toList(),
        "Tags".categoryTextDynamic:
            List.generate(data!.tags.length, (index) => data!.tags[index].name)
      };

  @override
  bool get enableTranslationToCN => App.locale.languageCode == "zh";

  @override
  void tapOnTag(String tag, String key) {
    context.to(() => SearchResultPage(keyword: tag, sourceKey: 'hitomi',));
  }

  @override
  Map<String, String> get headers =>
      {"User-Agent": webUA, "Referer": "https://hitomi.la/"};

  @override
  ThumbnailsData? get thumbnailsCreator => ThumbnailsData([], (page) async {
        try {
          var gg = GG();
          var images = <String>[];
          for (var file in data!.files) {
            images.add(await gg.urlFromUrlFromHash(
                data!.id, file, "webpsmallsmalltn", "webp", 'tn'));
          }
          return Res(images);
        } catch (e, s) {
          LogManager.addLog(LogLevel.error, "Network", "$e\n$s");
          return Res(null, errorMessage: e.toString());
        }
      }, 2);

  @override
  void onThumbnailTapped(int index) async {
    await History.findOrCreate(data!, page: index + 1);
    App.globalTo(() => ComicReadingPage.hitomi(
      data!,
      comic.link,
      initialPage: index + 1,
    ));
  }

  @override
  String? get title => comic.name;

  @override
  Card? get uploaderInfo => null;

  @override
  Future<bool> loadFavorite(HitomiComic data) async {
    return (await LocalFavoritesManager().find(data.id)).isNotEmpty;
  }

  @override
  String get id => data!.id;

  @override
  String get source => "hitomi";

  @override
  FavoriteItem toLocalFavoriteItem() =>
      FavoriteItem.fromHitomi(data!.toBrief(comic.link, cover));

  @override
  String get downloadedId => "hitomi${data!.id}";

  @override
  String get sourceKey => "hitomi";
}

void _downloadComic(
    HitomiComic comic, BuildContext context, String cover, String link) {
  if (downloadManager.downloaded.contains(comic.id)) {
    showToast(message: "已下载".tl);
    return;
  }
  for (var i in downloadManager.downloading) {
    if (i.id == comic.id) {
      showToast(message: "下载中".tl);
      return;
    }
  }
  downloadManager.addHitomiDownload(comic, cover, link);
  showToast(message: "已加入下载".tl);
}