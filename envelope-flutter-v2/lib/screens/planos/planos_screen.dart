import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/mes_provider.dart';
import '../../providers/usuarios_provider.dart';
import 'fixos_tab.dart';
import 'contas_tab.dart';
import 'metas_tab.dart';
import 'patrimonio_tab.dart';

class PlanosScreen extends ConsumerStatefulWidget {
  const PlanosScreen({super.key});

  @override
  ConsumerState<PlanosScreen> createState() => _PlanosScreenState();
}

class _PlanosScreenState extends ConsumerState<PlanosScreen>
    with TickerProviderStateMixin {
  late TabController _tab;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _atualizarTabs(bool isAdmin) {
    if (_isAdmin != isAdmin) {
      _isAdmin = isAdmin;
      final novoLength = isAdmin ? 4 : 3;
      if (_tab.length != novoLength) {
        _tab.dispose();
        _tab = TabController(length: novoLength, vsync: this);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mes = ref.watch(mesAtualProvider);
    final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
    final isAdmin = perfil?['role'] == 'admin';
    _atualizarTabs(isAdmin);

    return Column(
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        Container(
          color: AppColors.surf,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pagePad,
            MediaQuery.of(context).padding.top + 16,
            AppSpacing.pagePad,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Planos', style: AppTextStyles.title),
                  const Spacer(),
                  _MesSeletor(mes: mes),
                ],
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tab,
                indicatorColor: AppColors.acc,
                labelColor: AppColors.acc,
                unselectedLabelColor: AppColors.mu,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 2.5,
                isScrollable: isAdmin,
                tabAlignment: isAdmin ? TabAlignment.start : TabAlignment.fill,
                labelStyle: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
                unselectedLabelStyle: AppTextStyles.bodySm,
                tabs: [
                  const Tab(text: '📌  Fixos'),
                  const Tab(text: '🏦  Contas'),
                  const Tab(text: '🎯  Metas'),
                  if (isAdmin) const Tab(text: '💰  Patrimônio'),
                ],
              ),
            ],
          ),
        ),

        // ── Tab bodies ──────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              const FixosTab(),
              const ContasTab(),
              const MetasTab(),
              if (isAdmin) const PatrimonioTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Seletor de mês inline ──────────────────────────────────────────────────────

class _MesSeletor extends ConsumerWidget {
  final String mes;
  const _MesSeletor({required this.mes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => ref.read(mesAtualProvider.notifier).state =
              mesAnterior(ref.read(mesAtualProvider)),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.chevron_left_rounded,
                size: 20, color: AppColors.mu),
          ),
        ),
        Text(
          mesLabel(mes),
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        GestureDetector(
          onTap: () => ref.read(mesAtualProvider.notifier).state =
              mesProximo(ref.read(mesAtualProvider)),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.mu),
          ),
        ),
      ],
    );
  }
}
