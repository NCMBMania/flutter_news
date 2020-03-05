// ライブラリの読み込み
const request = require('superagent');
const NCMB = require('ncmb');

// 定数を定義
const applicationKey = '1f394bd4d2a0a80a45f0c5a86fea448b6b36d5a795ad2ce90ddb6ff7ad136fb2';
const clientKey = 'cdc44afd241a213a917f35d58344672ad60e72666bbbd7aa44c82172ea4fa398';

// NCMBの準備
const ncmb = new NCMB(applicationKey, clientKey);
const Feed = ncmb.DataStore('Feed');
const Entry = ncmb.DataStore('Entry');

// メイン処理
module.exports = async (req, res) => {
  if (!req.query.url) {
    return res.json({});
  }
  // キャッシュの検索
  const date = new Date;
  date.setHours(date.getHours() - 1);
  let feed = await Feed.equalTo('url', req.query.url).fetch();
  if (Object.keys(feed).length > 0) {
    if (new Date(feed.fetchDate.iso) > date) {
      res.json({
        objectId: feed.objectId,
        nextFetchDate: new Date(feed.fetchDate.iso)
      });
      return;
    }
  } else {
    feed = new Feed;
    feed.set('url', req.query.url);
  }
  // フィードを取得
  const url = `https://api.rss2json.com/v1/api.json?rss_url=${encodeURI(req.query.url)}`;
  response = await request
    .get(url)
    .send();
  const json = await response.body;
  for (const key in json.feed) {
    if (key !== 'items' && key !== 'url') {
      feed.set(key, json[key]);
    }
  }
  
  // フィールの中の記事を検索&登録
  const entries = [];
  const relation = new ncmb.Relation();
  for (const item of json.items) {
    let entry = await Entry.equalTo('guid', item.guid).fetch();
    if (Object.keys(entry).length > 0) {
      relation.add(entry);
    }
    entry = new Entry;
    for (const key in item) {
      if (['created', 'updated'].indexOf(key) > -1) {
        entry.set(key, new Date(item[key]));
      } else {
        entry.set(key, item[key]);
      }
    }
    relation.add(entry);
  }
  
  // フィードを更新
  feed.set('entries', relation);
  feed.set('fetchDate', new Date);
  const method = feed.objectId ? 'update' : 'save';
  try {
    await feed[method]();
    res.json({
      objectId: feed.objectId,
      nextFetchDate: feed.fetchDate
    });
  } catch (e) {
    console.log(e);
    res.json(e);
  }
}