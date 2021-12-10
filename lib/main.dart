import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ncmb/ncmb.dart';
import 'package:html/parser.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future main() async {
  await dotenv.load(fileName: '.env');
  var applicationKey =
      dotenv.get('APPLICATION_KEY', fallback: 'No application key found.');
  var clientKey = dotenv.get('CLIENT_KEY', fallback: 'No client key found.');
  NCMB(applicationKey, clientKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'News App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Noto Sans JP',
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale("ja", "JP"),
      ],
      home: const MyHomePage(title: 'News App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var listItem = [];
  var _selectedIndexValue = 0;
  @override
  void initState() {
    super.initState();
    getNews();
  }

  getNews() async {
    await login();
    var entry = NCMBQuery('Entry');
    entry.order('createDate');
    var ary = await entry.fetchAll();
    setState(() {
      listItem = ary;
    });
  }

  getFavorites() async {
    await login();
    var favorite = NCMBQuery('Favorite');
    favorite
      ..include('entry')
      ..order('createDate');
    var favorites = await favorite.fetchAll();
    var ary = favorites.map((f) => f.get('entry')).toList();
    debugPrint(ary[0].get('objectId'));
    setState(() {
      listItem = ary;
    });
  }

  login() async {
    // Login check
    var user = await NCMBUser.currentUser();
    if (user == null) {
      await NCMBUser.loginAsAnonymous();
    } else if (!(await user.enableSession())) {
      var authData = user.get('authData') as Map;
      await NCMBUser.logout();
      await NCMBUser.loginAsAnonymous(id: authData['anonymous']['id']);
    }
  }

  Future<void> changeList(value) async {
    if (value == 0) {
      await getNews();
    } else {
      await getFavorites();
    }
    setState(() => _selectedIndexValue = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              CupertinoSegmentedControl(
                children: const {
                  0: Text('All entries'),
                  1: Text('Favorited'),
                },
                groupValue: _selectedIndexValue,
                onValueChanged: (value) async {
                  await changeList(value);
                },
              ),
              Expanded(
                  child: ListView.builder(
                itemBuilder: (BuildContext context, int index) {
                  return Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.black38),
                        ),
                      ),
                      child: ListTile(
                        title: Text(listItem[index].get('title')),
                        subtitle: Text(
                            stripTags(listItem[index].get('description')),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                  settings:
                                      const RouteSettings(name: '/detail'),
                                  builder: (BuildContext context) =>
                                      MyDetailPage(object: listItem[index])));
                        },
                      ));
                },
                itemCount: listItem.length,
              ))
            ]));
  }

  String stripTags(String htmlString) {
    var document = parse(htmlString);
    return parse(document.body!.text).documentElement!.text;
  }
}

class MyDetailPage extends StatefulWidget {
  const MyDetailPage({Key? key, required this.object}) : super(key: key);
  final NCMBObject object;

  @override
  _MyDetailPageState createState() => _MyDetailPageState();
}

class _MyDetailPageState extends State<MyDetailPage> {
  bool favorited = false;
  NCMBObject? _favorite;

  @override
  void initState() {
    super.initState();
    checkFavorited();
  }

  IconData favoriteIcon() {
    return favorited ? Icons.star : Icons.star_border;
  }

  Future<void> favorite() async {
    if (favorited) {
      await removeFavorite();
    } else {
      await addFavorite();
    }
  }

  Future<void> addFavorite() async {
    var user = await NCMBUser.currentUser();
    var acl = NCMBAcl();
    acl
      ..setPublicReadAccess(false)
      ..setPublicWriteAccess(false)
      ..setUserReadAccess(user!, true)
      ..setUserWriteAccess(user, true);

    _favorite = NCMBObject('Favorite');
    _favorite!
      ..set('entry', widget.object)
      ..set('acl', acl);
    await _favorite!.save();
    setState(() {
      favorited = true;
    });
  }

  Future<void> removeFavorite() async {
    await _favorite?.delete();
    setState(() {
      favorited = false;
    });
  }

  Future<void> checkFavorited() async {
    setState(() {
      favorited = false;
    });
    var query = NCMBQuery('Favorite');
    query.equalTo('entry', widget.object);
    _favorite = await query.fetch();
    if (_favorite != null) {
      setState(() {
        favorited = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text(widget.object.get('title') as String),
            actions: <Widget>[
              IconButton(
                icon: Icon(favoriteIcon()),
                onPressed: () async {
                  await favorite();
                },
              ),
            ]),
        body: Center(
            child: SingleChildScrollView(
                child: Html(data: widget.object.get('content') as String))));
  }
}
