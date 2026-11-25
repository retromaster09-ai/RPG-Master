import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import 'campaigns.dart';
import 'cover_picker.dart';

class CampaignCard extends StatefulWidget {
  const CampaignCard({
    super.key,
    required this.campaign,
    required this.repository,
    required this.isOwner,
    required this.onOpen,
    this.onEditCover,
  });

  final Campaign campaign;
  final CampaignRepository repository;
  final bool isOwner;
  final VoidCallback onOpen;
  final VoidCallback? onEditCover;

  @override
  State<CampaignCard> createState() => _CampaignCardState();
}

class _CampaignCardState extends State<CampaignCard> {
  late Future<Uint8List>? _cover = _loadCover();

  Future<Uint8List>? _loadCover() {
    final hash = widget.campaign.coverHash;
    return hash == null
        ? null
        : widget.repository.readCampaignCover(widget.campaign, hash);
  }

  @override
  void didUpdateWidget(CampaignCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.campaign.id != widget.campaign.id ||
        oldWidget.campaign.coverHash != widget.campaign.coverHash) {
      _cover = _loadCover();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.primary.withValues(alpha: 0.45)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _CoverArt(
              future: _cover,
              layout: widget.campaign.coverLayout,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.47, 1],
                  colors: [
                    Color(0x770B0806),
                    Color(0x240B0806),
                    Color(0xF7080504),
                  ],
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xDB18130F),
                        border: Border.all(color: const Color(0xAAEAC695)),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        widget.isOwner ? 'Mestre' : 'Jogador',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: const Color(0xFFF5D4A8)),
                      ),
                    ),
                    const SizedBox(height: 67),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.campaign.name,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: const Color(0xFFFFF1DA),
                                  fontWeight: FontWeight.bold,
                                  shadows: const [
                                    Shadow(color: Colors.black, blurRadius: 12),
                                  ],
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFFFFE2BC),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.onEditCover case final edit?)
            Positioned(
              top: 5,
              right: 5,
              child: IconButton(
                onPressed: edit,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xC81A140F),
                  foregroundColor: const Color(0xFFFFE2BC),
                ),
                tooltip: widget.campaign.coverHash == null
                    ? 'Adicionar capa'
                    : 'Editar capa',
                icon: const Icon(Icons.image_outlined),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.layout, this.image, this.future});

  final CampaignCoverLayout layout;
  final Uint8List? image;
  final Future<Uint8List>? future;

  static Widget _defaultArt() => Image.asset(
    'assets/brand/adventurers.png',
    fit: BoxFit.cover,
    excludeFromSemantics: true,
  );

  Widget _render(Uint8List? bytes) {
    if (bytes == null) return _defaultArt();
    final alignment = Alignment(layout.x, layout.y);
    return ClipRect(
      child: ColoredBox(
        color: const Color(0xFF231812),
        child: Transform.scale(
          scale: layout.zoom,
          alignment: alignment,
          child: Image.memory(
            bytes,
            alignment: alignment,
            fit: layout.fill ? BoxFit.cover : BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => _defaultArt(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (image != null || future == null) return _render(image);
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) => _render(snapshot.data),
    );
  }
}

class CampaignCoverDialog extends StatefulWidget {
  const CampaignCoverDialog({
    super.key,
    required this.campaign,
    required this.repository,
  });

  final Campaign campaign;
  final CampaignRepository repository;

  @override
  State<CampaignCoverDialog> createState() => _CampaignCoverDialogState();
}

class _CampaignCoverDialogState extends State<CampaignCoverDialog> {
  late var _layout = widget.campaign.coverLayout;
  late String? _hash = widget.campaign.coverHash;
  late final Future<Uint8List>? _existing = _hash == null
      ? null
      : widget.repository.readCampaignCover(widget.campaign, _hash!);
  Uint8List? _image;
  bool _busy = false;
  String? _message;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final image = await pickCoverImage();
      if (!mounted || image == null) return;
      setState(() {
        _image = image;
        _layout = const CampaignCoverLayout();
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Não foi possível abrir a imagem. Escolha um PNG ou JPEG.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.repository.setCampaignCover(
        widget.campaign,
        _layout,
        hash: _hash,
        png: _image,
      );
      if (mounted) Navigator.pop(context);
    } on CampaignCoverConflict {
      if (mounted) {
        setState(
          () => _message = 'A capa mudou em outro aparelho. Feche e abra o cartão para ver a versão mais recente.',
        );
      }
    } on Exception {
      if (mounted) {
        setState(
          () => _message = 'Não foi possível salvar a capa. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _image != null || _hash != null;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Capa da campanha'),
        scrollable: true,
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1.8,
                  child: _CoverArt(
                    layout: _layout,
                    image: _image,
                    future: _hash == null ? null : _existing,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(hasImage ? 'Trocar imagem' : 'Escolher imagem'),
                  ),
                  if (hasImage)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _hash = null;
                              _image = null;
                              _layout = const CampaignCoverLayout();
                            }),
                      child: const Text('Usar arte padrão'),
                    ),
                ],
              ),
              if (hasImage) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Preencher o cartão'),
                  value: _layout.fill,
                  onChanged: _busy
                      ? null
                      : (fill) => setState(() {
                          _layout = CampaignCoverLayout(
                            fill: fill,
                            zoom: _layout.zoom,
                            x: _layout.x,
                            y: _layout.y,
                          );
                        }),
                ),
                Text('Zoom · ${_layout.zoom.toStringAsFixed(1)}×'),
                Slider(
                  value: _layout.zoom,
                  min: 1,
                  max: 3,
                  onChanged: _busy
                      ? null
                      : (zoom) => setState(() {
                          _layout = CampaignCoverLayout(
                            fill: _layout.fill,
                            zoom: zoom,
                            x: _layout.x,
                            y: _layout.y,
                          );
                        }),
                ),
              ],
              if (_message case final message?) Text(message),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Aguarde…' : 'Salvar capa'),
          ),
        ],
      ),
    );
  }
}
