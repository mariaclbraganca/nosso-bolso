import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../config/notificacoes_screen.dart';

/// Aparece na Home enquanto a captura do Nubank/iFood não tem permissão.
class HomeAvisoCaptura extends ConsumerStatefulWidget {
  const HomeAvisoCaptura({super.key});

  @override
  ConsumerState<HomeAvisoCaptura> createState() => _HomeAvisoCapturaState();
}

class _HomeAvisoCapturaState extends ConsumerState<HomeAvisoCaptura> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(permissaoCapturaProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(permissaoCapturaProvider).valueOrNull != false) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: NBSpacing.l),
      child: AvisoPermissaoCaptura(onConceder: () => pedirPermissaoCaptura(ref)),
    );
  }
}
