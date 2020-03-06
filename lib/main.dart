import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:ncmb/ncmb.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:html/parser.dart';
import 'package:flutter_html/flutter_html.dart';

void main() async {
  await DotEnv().load('.env');
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    NCMB ncmb = NCMB(DotEnv().env['APPLICATION_KEY'], DotEnv().env['CLIENT_KEY']);
    
    return MaterialApp(
      title: 'Flutter news app',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter news Home Page', ncmb: ncmb),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title, this.ncmb}) : super(key: key);
  final String title;
  NCMB ncmb;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class MyDetailPage extends StatefulWidget {
  MyDetailPage({Key key, this.ncmb, this.object}) : super(key: key);
  NCMB ncmb;
  NCMBObject object;
  @override
  _MyDetailPageState createState() => _MyDetailPageState();
}

class _MyDetailPageState extends State<MyDetailPage> {
  bool favorited;
  NCMBObject _favorite;
  
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
    var user = await widget.ncmb.User.CurrentUser();
    var acl = widget.ncmb.Acl();
    acl
      ..setPublicReadAccess(false)
      ..setPublicWriteAccess(false)
      ..setUserReadAccess(user.get('objectId'), true)
      ..setUserWriteAccess(user.get('objectId'), true);

    _favorite = widget.ncmb.Object('Favorite');
    _favorite
      ..set('entry', widget.object)
      ..set('acl', acl);
    await _favorite.save();
    setState(() {
      favorited = true;
    });
    
  }
  
  Future<void> removeFavorite() async {
    if (_favorite != null) {
      await _favorite.destroy();
    }
    setState(() {favorited = false;});
  }
  
  Future<void> checkFavorited() async {
    setState(() {favorited = false;});
    var query = widget.ncmb.Query('Favorite');
    query.equalTo('entry', widget.object);
    _favorite = await query.fetch();
    if (_favorite != null) {
      setState(() {favorited = true;});
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.object.get('title')),
        actions: <Widget>[
          IconButton(
            icon: Icon(favoriteIcon()),
            onPressed: () async {
              await favorite();
            },
          ),
        ]
      ),
      body: new Center(
        child: SingleChildScrollView(
          child: Html(
            data: widget.object.get('description')
          )
        )
      )
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  var listItem = [];
  var _selectedIndexValue = 0;
  @override
  void initState() {
    super.initState();
    getNews();
  }
  
  void getNews() async {
    await login();
    var entry = widget.ncmb.Query('Entry');
    entry.order('createDate');
    var ary = await entry.fetchAll();
    setState(() {
      listItem = ary;
    });
  }
  
  void getFavorites() async {
    await login();
    var favorite = widget.ncmb.Query('Favorite');
    favorite
      ..include('entry')
      ..order('createDate');
    var favorites = await favorite.fetchAll();
    var ary = favorites.map((f) => f.get('entry')).toList();
    setState(() {
      listItem = ary;
    });
  }
  
  void login() async {
    // Login check
    var user = await widget.ncmb.User.CurrentUser();
    if (user == null) {
      await widget.ncmb.User.loginAsAnonymous();
    } else if (!(await user.enableSession())) {
      var authData = user.get('authData') as Map;
      await widget.ncmb.User.logout();
      await widget.ncmb.User.loginAsAnonymous(id: authData['anonymous']['id']);
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
            children: {
              0: Text("All entries"),
              1: Text("Favorited"),
            },
            groupValue: _selectedIndexValue,
            onValueChanged: (value) async {
              await changeList(value);
            },
          ),
          new Expanded(
            child: ListView.builder(
              itemBuilder: (BuildContext context, int index) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.black38),
                      ),
                    ),
                    child: ListTile(
                      title: Text(listItem[index].get('title')),
                      subtitle: Text(stripTags(listItem[index].get('description')), 
                        overflow: TextOverflow.ellipsis, maxLines: 2
                      ),
                      onTap: () {
                        Navigator.push(context, new MaterialPageRoute<Null>(
                          settings: const RouteSettings(name: "/detail"),
                          builder: (BuildContext context) => new MyDetailPage(ncmb: widget.ncmb, object: listItem[index])
                        ));
                      },
                    )
                );
              },
              itemCount: listItem.length,
            )
          )
        ]
      )
    );
  }
  
  String stripTags(String htmlString) {
    var document = parse(htmlString);
    return parse(document.body.text).documentElement.text;
  }
}
