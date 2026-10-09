/// 琴头布局：吉他需 3+3 / 单侧6弦，预留 4弦/Ukulele 扩展
enum HeadstockLayout {
  threePlusThree, // 两侧各 3（Les Paul / dreadnought 式）
  sixInLine, // 单侧 6（Strat 式）
  fourInLine, // 预留：贝司
  threePlusOne, // 预留：部分贝司/Ukulele 变体
}

extension HeadstockLayoutLabel on HeadstockLayout {
  String get label => switch (this) {
        HeadstockLayout.threePlusThree => '3+3 双侧',
        HeadstockLayout.sixInLine => '单侧 6 弦',
        HeadstockLayout.fourInLine => '单侧 4 弦',
        HeadstockLayout.threePlusOne => '3+1',
      };
}
