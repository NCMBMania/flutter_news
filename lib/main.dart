import 'package:flutter/material.dart';
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
    print(DotEnv().env['APPLICATION_KEY']);
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.object.get('title'))),
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
  
  @override
  void initState() {
    super.initState();
    getNews();
  }
  
  void getNews() async {
    var entry = widget.ncmb.Query('Entry');
    entry.order('createDate');
    var _listItem = await entry.fetchAll();
    setState(() {
      listItem = _listItem;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title),),
      body: ListView.builder(
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
            ));},
        itemCount: listItem.length,
      ),
    );
  }
  
  String stripTags(String htmlString) {
    var document = parse(htmlString);
    return parse(document.body.text).documentElement.text;
  }
}
