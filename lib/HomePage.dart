import 'dart:convert' show json;

import 'package:audio_player/app_colours.dart' as AppColors;
import 'package:audio_player/my_tabs.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  List audioFiles = [];

  late ScrollController _scrollController;
  late TabController _tabController;

  ReadData() async {
    await DefaultAssetBundle.of(context).loadString("json/audio.json").then((
      a,
    ) {
      setState(() {
        audioFiles = json.decode(a);
      });
    });
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);
    _scrollController = ScrollController();

    ReadData();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Scaffold(
          body: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(left: 20, right: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ImageIcon(
                      AssetImage("images/menu.png"),
                      size: 28,
                      color: Colors.black,
                    ),
                    Row(
                      children: [
                        Icon(Icons.search),
                        SizedBox(width: 10),
                        Icon(Icons.notifications),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 20),
                    child: Text("Popular", style: TextStyle(fontSize: 30)),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Container(
                height: 180,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: -20,
                      right: 0,
                      child: Container(
                        height: 180,
                        child: PageView.builder(
                          controller: PageController(viewportFraction: 0.8),
                          itemCount: audioFiles.length,
                          itemBuilder: (_, i) {
                            return Container(
                              height: 180,
                              width: MediaQuery.of(context).size.width,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                image: DecorationImage(
                                  image: AssetImage(audioFiles[i]["img"]),
                                  fit: BoxFit.fill,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: NestedScrollView(
                  controller: _scrollController,
                  headerSliverBuilder: (BuildContext context, bool isScroll) {
                    return [
                      SliverAppBar(
                        pinned: true,
                        backgroundColor: Colors.white,
                        bottom: PreferredSize(
                          preferredSize: Size.fromHeight(50),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            child: TabBar(
                              indicatorPadding: const EdgeInsets.all(0),
                              indicatorSize: TabBarIndicatorSize.label,
                              labelPadding: const EdgeInsets.only(right: 10),
                              controller: _tabController,
                              isScrollable: true,
                              indicator: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.3),
                                    blurRadius: 7,
                                    offset: Offset(0, 0),
                                  ),
                                ],
                              ),
                              tabs: [
                                AppTabs(
                                  color: AppColors.menuColor,
                                  text: "Quran",
                                ),
                                AppTabs(
                                  color: AppColors.menu2Color,
                                  text: "Lectures",
                                ),
                                AppTabs(
                                  color: AppColors.menu3Color,
                                  text: "Reminders",
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      Material(
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.grey),
                          title: Text("Content"),
                        ),
                      ),
                      Material(
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.grey),
                          title: Text("Content"),
                        ),
                      ),
                      Material(
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.grey),
                          title: Text("Content"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
