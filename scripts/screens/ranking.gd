extends "res://scripts/screens/screen.gd"
## Overlay: the local ranking of saved missions (GameState.ranking). Opened with main.overlay("ranking").


func enter(_args: Dictionary) -> void:
	var v := Kit.overlay(self, tr("Mission ranking"), 760, 560, queue_free)
	var ranking: Array = GameState.ranking
	if ranking.is_empty():
		v.add_child(Kit.lbl(tr("The board is waiting for its first mission. Be the one."), Kit.T_BODY, Kit.C_DIM))
		return
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 22)
	sc.add_child(g)
	for hdr in ["#", tr("Team"), tr("Points"), tr("Mission"), tr("Difficulty")]:
		g.add_child(Kit.caps(hdr))
	for i in ranking.size():
		var e: Dictionary = ranking[i]
		var podium: Color = [Kit.C_GOLD, Kit.C_TEXT, Kit.C_WARN][i] if i < 3 else Kit.C_DIM
		g.add_child(Kit.lbl(str(i + 1), Kit.T_BODY, podium, Kit.FONT_B))
		g.add_child(Kit.lbl(str(e.team), Kit.T_BODY, Kit.C_TEXT, Kit.FONT_B))
		g.add_child(Kit.lbl("%d  ·  %s" % [int(e.score), e.grade], Kit.T_BODY, Kit.C_GOLD, Kit.FONT_B))
		# saved by its English name, shown in the player's language
		g.add_child(Kit.lbl(tr(str(e.scenario)), Kit.T_SMALL + 1, Kit.C_DIM))
		g.add_child(Kit.lbl(tr(str(e.difficulty)), Kit.T_SMALL + 1, Kit.C_DIM))
