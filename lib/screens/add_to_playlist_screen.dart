import 'package:flutter/material.dart';

class AddToPlaylistScreen extends StatefulWidget {
  final int playlistId;
  final String playlistName;

  const AddToPlaylistScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  @override
  State<AddToPlaylistScreen> createState() => _AddToPlaylistScreenState();
}

class _AddToPlaylistScreenState extends State<AddToPlaylistScreen> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
