extends Control
## SCHMUGGEL – Version 1
## Dieses eine Script baut die komplette Oberfläche per Code.
## Einfach an einen "Control"-Node hängen und die Szene starten.

# =====================================================================
#  SPIELDATEN – hier passt du das Spiel an oder erweiterst es.
#  Neue Ware / neues Versteck / neue Ausrede = einfach einen weiteren
#  Eintrag { ... } in die passende Liste schreiben. Fertig.
# =====================================================================

const START_GELD := 500

# "einkauf"  = Preis hier, "verkauf" = Preis im Nachbarland (pro Stück)
# "risiko"   = wird zur Fund-Chance des Verstecks addiert (0.10 = +10 %)
# "strafe"   = Strafe in € pro Stück, wenn du erwischt wirst
const WAREN := [
	{"name": "Zigaretten", "einkauf": 20, "verkauf": 40, "risiko": 0.05, "strafe": 15},
	{"name": "Schnaps", "einkauf": 50, "verkauf": 110, "risiko": 0.10, "strafe": 40},
	{"name": "Gefälschte Uhren", "einkauf": 120, "verkauf": 300, "risiko": 0.20, "strafe": 100},
]

# "kapazitaet" = wie viele Stück Ware hineinpassen
# "entdeckung" = Chance, dass die Ware bei einer Durchsuchung gefunden wird (0.25 = 25 %)
const VERSTECKE := [
	{"name": "Autositze", "kapazitaet": 4, "entdeckung": 0.25},
	{"name": "Motorhaube", "kapazitaet": 3, "entdeckung": 0.35},
	{"name": "Handschuhfach", "kapazitaet": 2, "entdeckung": 0.55},
	{"name": "Eigene Tasche", "kapazitaet": 2, "entdeckung": 0.45},
	{"name": "Fracht", "kapazitaet": 8, "entdeckung": 0.65},
]

# "glaubwuerdigkeit" = Chance, dass der Kontrolleur dir glaubt (0.75 = 75 %).
# Glaubt er dir nicht, wird das Auto durchsucht.
const AUSREDEN := [
	{"text": "Ich besuche meine Oma.", "glaubwuerdigkeit": 0.75},
	{"text": "Ich bin auf Geschäftsreise.", "glaubwuerdigkeit": 0.60},
	{"text": "Ich mache Urlaub am See.", "glaubwuerdigkeit": 0.65},
	{"text": "Äh ... einfach so?", "glaubwuerdigkeit": 0.20},
]

# Nichts wird zu 100 % gefunden – sonst wäre ein Versteck sinnlos.
const MAX_FUND_CHANCE := 0.95

# Darstellung: Das Spiel wird für diese Größe gebaut und automatisch
# auf den Tablet-Bildschirm skaliert.
const BASIS_AUFLOESUNG := Vector2i(1280, 800)
const SCHRIFT_GROESSE := 26
const TITEL_GROESSE := 38
const KNOPF_HOEHE := 70

# =====================================================================
#  SPIELZUSTAND
# =====================================================================

var geld := START_GELD
var runde := 1
var gekauft: Array[int] = []   # gekauft[w]      = Stück von WAREN[w] im Auto
var versteckt: Array = []      # versteckt[v][w] = Stück von WAREN[w] in VERSTECKE[v]
var gewaehlte_ware := 0        # welche Ware du beim Verstecken gerade "in der Hand" hast

# Oberflächen-Elemente, die wir immer wieder füllen
var status_label: Label
var titel_label: Label
var inhalt: VBoxContainer


func _ready() -> void:
	_pruefe_daten()
	_baue_oberflaeche()
	_neues_spiel()


# =====================================================================
#  ABLAUF EINER RUNDE: Markt -> Verstecken -> Grenze -> (Durchsuchung) -> Ergebnis
# =====================================================================

func _neues_spiel() -> void:
	geld = START_GELD
	runde = 1
	_leere_auto()
	_zeige_markt()


func _naechste_runde() -> void:
	runde += 1
	_zeige_markt()


# ---------- 1. MARKT: Ware kaufen ----------

func _zeige_markt() -> void:
	_neuer_bildschirm("Markt – Ware einkaufen")
	_text("Kauf hier billig ein und verkauf im Nachbarland teurer.\nPlatz im Auto: %d von %d belegt." % [_summe(gekauft), _gesamt_kapazitaet()])
	for w in WAREN.size():
		var ware: Dictionary = WAREN[w]
		var zeile := _zeile()
		_text("%s – Kauf %d € | Verkauf %d € | Risiko +%d %%\nIm Auto: %d Stück" % [
			ware.name, ware.einkauf, ware.verkauf, roundi(ware.risiko * 100), gekauft[w]], zeile)
		var minus := _knopf("-", _zurueckgeben.bind(w), zeile)
		minus.disabled = gekauft[w] == 0
		var plus := _knopf("+", _kaufen.bind(w), zeile)
		plus.disabled = geld < ware.einkauf or _summe(gekauft) >= _gesamt_kapazitaet()
	_knopf("Weiter zum Verstecken", _zeige_verstecken)


func _kaufen(w: int) -> void:
	geld -= WAREN[w].einkauf
	gekauft[w] += 1
	_zeige_markt()


func _zurueckgeben(w: int) -> void:
	geld += WAREN[w].einkauf
	gekauft[w] -= 1
	_zeige_markt()


# ---------- 2. VERSTECKEN: Ware auf die Verstecke verteilen ----------

func _zeige_verstecken() -> void:
	# Ist die gewählte Ware schon komplett versteckt, nimm automatisch die nächste.
	if _offen(gewaehlte_ware) == 0:
		for w in WAREN.size():
			if _offen(w) > 0:
				gewaehlte_ware = w
				break

	var offen := _summe_offen()
	_neuer_bildschirm("Verstecken – wohin mit der Ware?")
	if offen > 0:
		_text("Ware oben antippen, dann beim Versteck \"Hier rein\". Noch offen: %d Stück." % offen)
	else:
		_text("Alles versteckt! Bereit für die Grenze.")

	# Auswahl: welche Ware soll als Nächstes versteckt werden?
	var auswahl := _zeile()
	for w in WAREN.size():
		var knopf := _knopf("%s (%d)" % [WAREN[w].name, _offen(w)], _waehle_ware.bind(w), auswahl)
		knopf.toggle_mode = true
		knopf.button_pressed = w == gewaehlte_ware
		knopf.disabled = _offen(w) == 0
		knopf.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Eine Zeile pro Versteck
	for v in VERSTECKE.size():
		var versteck: Dictionary = VERSTECKE[v]
		var belegt := _summe(versteckt[v])
		var zeile := _zeile()
		_text("%s  [%d/%d]  Fund-Chance %d %%\n%s" % [
			versteck.name, belegt, versteck.kapazitaet, roundi(_fund_chance(v) * 100), _inhalt_text(v)], zeile)
		var rein := _knopf("Hier rein", _verstecken.bind(v), zeile)
		rein.disabled = _offen(gewaehlte_ware) == 0 or belegt >= versteck.kapazitaet
		var leeren := _knopf("Leeren", _versteck_leeren.bind(v), zeile)
		leeren.disabled = belegt == 0

	var weiter := _knopf("Zur Grenze fahren", _zeige_grenze)
	weiter.disabled = offen > 0


func _waehle_ware(w: int) -> void:
	gewaehlte_ware = w
	_zeige_verstecken()


func _verstecken(v: int) -> void:
	versteckt[v][gewaehlte_ware] += 1
	_zeige_verstecken()


func _versteck_leeren(v: int) -> void:
	versteckt[v] = _nullen(WAREN.size())
	_zeige_verstecken()


# ---------- 3. GRENZKONTROLLE: Ausrede wählen ----------

func _zeige_grenze() -> void:
	_neuer_bildschirm("Grenzkontrolle")
	_text("Ein Grenzbeamter klopft an die Scheibe:\n\"Guten Tag. Warum wollen Sie ins Nachbarland?\"")
	for a in AUSREDEN.size():
		_knopf(AUSREDEN[a].text, _ausrede_gewaehlt.bind(a))


func _ausrede_gewaehlt(a: int) -> void:
	_neuer_bildschirm("Grenzkontrolle")
	_text("Du sagst: \"%s\"" % AUSREDEN[a].text)
	if randf() < AUSREDEN[a].glaubwuerdigkeit:
		_text("Der Beamte nickt: \"Alles klar. Gute Fahrt!\"")
		_knopf("Weiterfahren", _runde_beenden.bind(false))
	else:
		_text("Der Beamte runzelt die Stirn: \"Das glaube ich Ihnen nicht. Bitte rechts ranfahren – Fahrzeugkontrolle!\"")
		_knopf("Durchsuchung über dich ergehen lassen", _zeige_durchsuchung)


# ---------- 4. DURCHSUCHUNG: jedes belegte Versteck wird geprüft ----------

func _zeige_durchsuchung() -> void:
	_neuer_bildschirm("Durchsuchung")
	var erwischt := false
	var auto_leer := true
	for v in VERSTECKE.size():
		if _summe(versteckt[v]) == 0:
			continue
		auto_leer = false
		var gefunden := randf() < _fund_chance(v)
		erwischt = erwischt or gefunden
		var ergebnis := _text("%s: %s" % [VERSTECKE[v].name, "GEFUNDEN!" if gefunden else "nichts gefunden"])
		ergebnis.add_theme_color_override("font_color", Color("ef476f") if gefunden else Color("06d6a0"))
	if auto_leer:
		_text("Das Auto ist leer – die Beamten finden nichts.")
	_knopf("Weiter", _runde_beenden.bind(erwischt))


# ---------- 5. ERGEBNIS: verkaufen oder Strafe zahlen ----------

func _runde_beenden(erwischt: bool) -> void:
	var einkauf := _wert("einkauf")
	if erwischt:
		var strafe := _wert("strafe")
		geld = maxi(geld - strafe, 0)
		_neuer_bildschirm("Erwischt!")
		_text("Deine Ware (Einkaufswert %d €) wurde beschlagnahmt.\nDazu kommt eine Strafe von %d €." % [einkauf, strafe])
	else:
		var erloes := _wert("verkauf")
		geld += erloes
		_neuer_bildschirm("Durchgekommen!")
		_text("Du verkaufst deine Ware für %d €.\nEinkauf: %d €   Gewinn: %d €" % [erloes, einkauf, erloes - einkauf])
	_leere_auto()

	# Game Over, wenn du dir nicht einmal mehr die billigste Ware leisten kannst (z. B. bei 0 €)
	if geld < _billigster_preis():
		titel_label.text = "GAME OVER"
		_text("Du bist pleite! Du hast es bis Runde %d geschafft." % runde)
		_knopf("Neues Spiel", _neues_spiel)
	else:
		_knopf("Nächste Runde", _naechste_runde)


# =====================================================================
#  RECHEN-HELFER
# =====================================================================

# Ein Array mit lauter Nullen, z. B. [0, 0, 0]
func _nullen(anzahl: int) -> Array[int]:
	var liste: Array[int] = []
	liste.resize(anzahl)
	liste.fill(0)
	return liste


func _leere_auto() -> void:
	gekauft = _nullen(WAREN.size())
	versteckt.clear()
	for v in VERSTECKE.size():
		versteckt.append(_nullen(WAREN.size()))


func _summe(liste: Array) -> int:
	var ergebnis := 0
	for zahl in liste:
		ergebnis += zahl
	return ergebnis


# Wie viele Stück von Ware w sind gekauft, aber noch nicht versteckt?
func _offen(w: int) -> int:
	var drin := 0
	for v in VERSTECKE.size():
		drin += versteckt[v][w]
	return gekauft[w] - drin


func _summe_offen() -> int:
	var ergebnis := 0
	for w in WAREN.size():
		ergebnis += _offen(w)
	return ergebnis


func _gesamt_kapazitaet() -> int:
	var ergebnis := 0
	for versteck in VERSTECKE:
		ergebnis += versteck.kapazitaet
	return ergebnis


# Fund-Chance eines Verstecks = Grund-Chance + höchstes Risiko der Ware darin
func _fund_chance(v: int) -> float:
	var risiko := 0.0
	for w in WAREN.size():
		if versteckt[v][w] > 0:
			risiko = maxf(risiko, WAREN[w].risiko)
	return minf(VERSTECKE[v].entdeckung + risiko, MAX_FUND_CHANCE)


# Text wie "2x Zigaretten, 1x Schnaps" für ein Versteck
func _inhalt_text(v: int) -> String:
	var teile := PackedStringArray()
	for w in WAREN.size():
		if versteckt[v][w] > 0:
			teile.append("%dx %s" % [versteckt[v][w], WAREN[w].name])
	return "leer" if teile.is_empty() else ", ".join(teile)


# Summe über alle gekauften Waren, z. B. _wert("verkauf") = Verkaufserlös
func _wert(schluessel: String) -> int:
	var ergebnis := 0
	for w in WAREN.size():
		ergebnis += gekauft[w] * WAREN[w][schluessel]
	return ergebnis


func _billigster_preis() -> int:
	var preis: int = WAREN[0].einkauf
	for ware in WAREN:
		preis = mini(preis, ware.einkauf)
	return preis


# Findet Tippfehler in den Spieldaten oben schon beim Start (nur beim Testen im Editor aktiv)
func _pruefe_daten() -> void:
	assert(not WAREN.is_empty() and not VERSTECKE.is_empty() and not AUSREDEN.is_empty(), "Jede Liste braucht mindestens einen Eintrag")
	for ware in WAREN:
		assert(ware.has_all(["name", "einkauf", "verkauf", "risiko", "strafe"]), "Ware unvollständig: " + str(ware))
	for versteck in VERSTECKE:
		assert(versteck.has_all(["name", "kapazitaet", "entdeckung"]), "Versteck unvollständig: " + str(versteck))
	for ausrede in AUSREDEN:
		assert(ausrede.has_all(["text", "glaubwuerdigkeit"]), "Ausrede unvollständig: " + str(ausrede))


# =====================================================================
#  OBERFLÄCHE – alles per Code gebaut
# =====================================================================

func _baue_oberflaeche() -> void:
	# Spiel automatisch auf jede Bildschirmgröße skalieren
	var fenster := get_window()
	fenster.content_scale_size = BASIS_AUFLOESUNG
	fenster.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	fenster.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Theme.new()
	theme.default_font_size = SCHRIFT_GROESSE  # gilt für alle Texte und Knöpfe

	var hintergrund := ColorRect.new()
	hintergrund.color = Color("1d2733")
	hintergrund.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hintergrund)

	var rahmen := MarginContainer.new()
	rahmen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for seite in ["left", "right", "top", "bottom"]:
		rahmen.add_theme_constant_override("margin_" + seite, 16)
	add_child(rahmen)

	var spalte := VBoxContainer.new()
	spalte.add_theme_constant_override("separation", 8)
	rahmen.add_child(spalte)

	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color("ffd166"))
	spalte.add_child(status_label)

	titel_label = Label.new()
	titel_label.add_theme_font_size_override("font_size", TITEL_GROESSE)
	spalte.add_child(titel_label)

	spalte.add_child(HSeparator.new())

	# Falls ein Bildschirm doch mal zu voll wird, kann man scrollen
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	spalte.add_child(scroll)

	inhalt = VBoxContainer.new()
	inhalt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inhalt.add_theme_constant_override("separation", 10)
	scroll.add_child(inhalt)


# Leert den Inhaltsbereich, setzt die Überschrift und aktualisiert Geld/Runde
func _neuer_bildschirm(titel: String) -> void:
	titel_label.text = titel
	status_label.text = "Geld: %d €   ·   Runde %d" % [geld, runde]
	for kind in inhalt.get_children():
		kind.queue_free()


# Fügt einen Text hinzu (in den Inhaltsbereich oder in eine Zeile)
func _text(text: String, eltern: Control = null) -> Label:
	if eltern == null:
		eltern = inhalt
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eltern.add_child(label)
	return label


# Fügt einen großen Touch-Knopf hinzu, der beim Antippen "aktion" ausführt
func _knopf(text: String, aktion: Callable, eltern: Control = null) -> Button:
	if eltern == null:
		eltern = inhalt
	var knopf := Button.new()
	knopf.text = text
	knopf.custom_minimum_size = Vector2(160, KNOPF_HOEHE)
	knopf.pressed.connect(aktion)
	eltern.add_child(knopf)
	return knopf


# Eine waagerechte Zeile (Text links, Knöpfe rechts)
func _zeile() -> HBoxContainer:
	var zeile := HBoxContainer.new()
	zeile.add_theme_constant_override("separation", 10)
	inhalt.add_child(zeile)
	return zeile
