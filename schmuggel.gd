extends Node
## SCHMUGGEL – Version 2: jetzt in 3D!
## Dieses eine Script baut die komplette 3D-Welt und die Oberfläche per Code.
## Einfach an einen beliebigen Node hängen (am besten einen Node3D) und die Szene starten.
##
## Ablauf einer Runde:
##   Handy (Ware kaufen) -> ums Auto gehen (verstecken) -> selbst zur Maut fahren
##   -> Ausrede wählen -> (Durchsuchung live mit ansehen) -> Ergebnis
##
## Fahren: Knöpfe unten auf dem Bildschirm (mehrere Finger gleichzeitig gehen)
## oder Tastatur: W/↑ Gas, S/↓ Bremse, R rückwärts, A/D oder ←/→ lenken.

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

# Reihenfolge = dein Weg ums Auto: Mit den Pfeilen gehst du von Versteck zu Versteck.
# "kapazitaet" = wie viele Stück Ware hineinpassen
# "entdeckung" = Chance, dass die Ware bei einer Durchsuchung gefunden wird (0.25 = 25 %)
# "winkel"     = von wo man draufschaut (0 = von vorne, 90 = rechts, 180 = hinten, 270 = links)
# "punkt"      = wo das Versteck am Auto sitzt (x = rechts, y = hoch, z = nach hinten; das Auto ist 4,2 m lang)
const VERSTECKE := [
	{"name": "Motorhaube", "kapazitaet": 3, "entdeckung": 0.35, "winkel": 15, "punkt": Vector3(0, 0.95, -1.5)},
	{"name": "Handschuhfach", "kapazitaet": 2, "entdeckung": 0.55, "winkel": 75, "punkt": Vector3(0.9, 1.1, -0.5)},
	{"name": "Fracht", "kapazitaet": 8, "entdeckung": 0.65, "winkel": 180, "punkt": Vector3(0, 0.9, 2.15)},
	{"name": "Eigene Tasche", "kapazitaet": 2, "entdeckung": 0.45, "winkel": 235, "punkt": Vector3(-0.9, 1.1, 0.9)},
	{"name": "Autositze", "kapazitaet": 4, "entdeckung": 0.25, "winkel": 295, "punkt": Vector3(-0.9, 1.1, -0.2)},
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

# ---------- Fahren & Maut ----------
const MAUT_ENTFERNUNG := 150.0   # so viele Meter fährst du bis zur Maut
const SPUREN := 4                # Mautspuren – nur eine ist offen (grünes Licht)
const SPUR_BREITE := 4.5
const TEMPOLIMIT := 30           # km/h kurz vor der Maut
const MAX_TEMPO := 20.0          # Meter pro Sekunde (20 m/s = 72 km/h)
const RUECKWAERTS_TEMPO := 4.0
const BESCHLEUNIGUNG := 6.0
const BREMSKRAFT := 14.0
const ROLLWIDERSTAND := 2.0
const LENKUNG := 0.9             # wie schnell das Auto bei voller Fahrt einlenkt

# Fahrfehler machen den Beamten misstrauisch. "verdacht" wird von der
# Glaubwürdigkeit deiner Ausrede abgezogen (0.10 = 10 % weniger Chance).
const FAHRFEHLER := {
	"zu_schnell": {"text": "Viel zu schnell auf die Maut zugerast!", "verdacht": 0.15},
	"leitplanke": {"text": "Leitplanke gestreift!", "verdacht": 0.05},
	"haeuschen": {"text": "Ans Mauthäuschen gekracht!", "verdacht": 0.20},
	"schranke": {"text": "Schranke gerammt!", "verdacht": 0.25},
	"falsche_spur": {"text": "Falsche Spur – die ist zu! Setz zurück (R).", "verdacht": 0.10},
	"ungenau": {"text": "Nicht ganz an der Linie gehalten.", "verdacht": 0.10},
	"weit_weg": {"text": "Viel zu weit weg von der Linie gehalten!", "verdacht": 0.25},
}
const MIN_GLAUBWUERDIGKEIT := 0.05   # ein kleines bisschen Glück bleibt immer

# Darstellung: Das Spiel wird für diese Größe gebaut und automatisch
# auf den Tablet-Bildschirm skaliert.
const BASIS_AUFLOESUNG := Vector2i(1280, 800)
const SCHRIFT_GROESSE := 26
const TITEL_GROESSE := 38
const KNOPF_HOEHE := 70
const GELB := Color("ffd166")
const GRUEN := Color("06d6a0")
const ROT := Color("ef476f")

# Wo die Infokarte steht: erst die Anker [links, oben, rechts, unten]
# (0 = linker/oberer Bildschirmrand, 1 = rechter/unterer), dann der Abstand dazu in Pixeln.
const KARTEN := {
	"handy": [0.5, 0.5, 0.5, 0.5, -260, -370, 260, 370],
	"seite": [1, 0, 1, 1, -500, 64, -16, -16],
	"unten": [0, 1, 1, 1, 16, -400, -16, -16],
	"mitte": [0.5, 0.5, 0.5, 0.5, -400, -250, 400, 250],
}

# Maße der Welt in Metern – nur ändern, wenn du auch die Modelle unten änderst
const MAUT_Z := -MAUT_ENTFERNUNG   # in Godot geht "nach vorne" Richtung -Z
const SCHRANKE_Z := MAUT_Z - 4.0
const AUTO_HALBE_LAENGE := 2.1
const AUTO_HALBE_BREITE := 0.9
const INSEL_HALBE_BREITE := 0.5
const INSEL_HALBE_LAENGE := 4.0
const SITZ := Vector3(-0.4, 1.2, 0.3)   # Augen des Fahrers im Auto

# =====================================================================
#  SPIELZUSTAND
# =====================================================================

var geld := START_GELD
var runde := 1
var gekauft: Array[int] = []   # gekauft[w]      = Stück von WAREN[w] im Auto
var versteckt: Array = []      # versteckt[v][w] = Stück von WAREN[w] in VERSTECKE[v]
var gewaehlte_ware := 0        # welche Ware du beim Verstecken gerade "in der Hand" hast
var aktuelles_versteck := 0    # vor welchem Versteck du gerade stehst
var verdacht := 0.0            # wie misstrauisch der Beamte durch deine Fahrweise ist
var offene_spur := 0

# Fahren
var faehrt := false
var kamera_folgt := false      # sitzt die Kamera im Auto?
var tempo := 0.0               # Meter pro Sekunde, negativ = rückwärts
var lenkung := 0.0             # -1 (rechts) bis 1 (links)
var kopf_drehung := 0.0        # zum Beamten rüberschauen
var kontakt := ""              # woran das Auto gerade stößt – jeder Stoß zählt nur einmal
var tempo_geprueft := false
var falsche_spur_gemeldet := false
var halte_zeit := 0.0
var finger := {}               # Touch-Nummer -> Position, damit Gas und Lenken gleichzeitig gehen

# 3D-Welt
var kamera: Camera3D
var auto: Node3D
var lenkrad: MeshInstance3D
var tacho: Label3D
var handy: Node3D
var beamter: Node3D
var schranken: Array[Node3D] = []
var ampeln: Array[MeshInstance3D] = []
var marker: Array[MeshInstance3D] = []   # leuchtende Punkte an den Verstecken

# Oberflächen-Elemente, die wir immer wieder füllen
var status_label: Label
var titel_label: Label
var meldung_label: Label
var hinweis_label: Label
var verdacht_label: Label
var inhalt: VBoxContainer
var karte: PanelContainer
var karten_stil: StyleBoxFlat
var handy_stil: StyleBoxFlat
var fahr_hud: Control
var pedale := {}               # Name -> Knopf auf dem Bildschirm
var meldung_tween: Tween


func _ready() -> void:
	_pruefe_daten()
	_baue_welt()
	_baue_oberflaeche()
	_neues_spiel()


func _process(delta: float) -> void:
	if faehrt:
		_fahre(delta)
	if kamera_folgt:
		kamera.global_transform = _fahrer_blick(kopf_drehung)


# =====================================================================
#  ABLAUF EINER RUNDE: Handy -> Verstecken -> Fahren -> Maut -> (Durchsuchung) -> Ergebnis
# =====================================================================

func _neues_spiel() -> void:
	geld = START_GELD
	runde = 1
	_neue_runde()


func _naechste_runde() -> void:
	runde += 1
	_neue_runde()


func _neue_runde() -> void:
	_leere_auto()
	verdacht = 0.0
	tempo = 0.0
	lenkung = 0.0
	kopf_drehung = 0.0
	kontakt = ""
	tempo_geprueft = false
	falsche_spur_gemeldet = false
	tacho.text = "0 km/h"
	auto.position = Vector3(_spur_mitte(int(SPUREN / 2.0)), 0, 0)
	auto.rotation = Vector3.ZERO
	# Jede Runde ist eine andere Spur offen
	offene_spur = randi() % SPUREN
	for i in SPUREN:
		schranken[i].rotation.z = 0.0
		_faerbe(ampeln[i], GRUEN if i == offene_spur else ROT, true)
	beamter.position = Vector3(_insel_x(offene_spur), 0.15, MAUT_Z - 0.5)
	beamter.rotation = Vector3(0, PI, 0)   # schaut den ankommenden Autos entgegen
	_marker_aus()
	_zeige_handy()


# ---------- 1. HANDY: Ware kaufen ----------

func _zeige_handy() -> void:
	faehrt = false
	kamera_folgt = false
	_karte_weg()
	# Du stehst vorne neben deinem Auto, schaust Richtung Grenze ...
	var augen := auto.to_global(Vector3(-2.2, 1.65, -3.0))
	var ziel := auto.to_global(Vector3(1.5, 1.6, -30))
	kamera.global_transform = _blick(augen, ziel)
	# ... und holst dein Handy raus
	handy.visible = true
	handy.global_position = augen + ((ziel - augen) * Vector3(1, 0, 1)).normalized() * 0.36 + Vector3(0, -0.42, 0)
	handy.look_at(augen)
	await get_tree().create_timer(0.6).timeout
	await _tween(kamera, "global_transform", _blick(augen, handy.global_position), 1.2)
	_zeige_markt()


func _zeige_markt() -> void:
	_neuer_bildschirm("Schmuggel-Shop", "handy")
	_text("Kauf hier billig ein und verkauf drüben teurer.\nPlatz im Auto: %d von %d" % [_summe(gekauft), _gesamt_kapazitaet()])
	for w in WAREN.size():
		var ware: Dictionary = WAREN[w]
		_text("%s\nKauf %d € · Verkauf %d €\nRisiko +%d %%" % [
			ware.name, ware.einkauf, ware.verkauf, roundi(ware.risiko * 100)])
		var zeile := _zeile()
		var minus := _knopf("-", _zurueckgeben.bind(w), zeile)
		minus.disabled = gekauft[w] == 0
		_text("%d Stück" % gekauft[w], zeile).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var plus := _knopf("+", _kaufen.bind(w), zeile)
		plus.disabled = geld < ware.einkauf or _summe(gekauft) >= _gesamt_kapazitaet()
	_knopf("Fertig – Handy weg", _handy_weg)


func _kaufen(w: int) -> void:
	geld -= WAREN[w].einkauf
	gekauft[w] += 1
	_zeige_markt()


func _zurueckgeben(w: int) -> void:
	geld += WAREN[w].einkauf
	gekauft[w] -= 1
	_zeige_markt()


func _handy_weg() -> void:
	_karte_weg()
	var augen := kamera.global_position
	await _tween(kamera, "global_transform", _blick(augen, auto.to_global(Vector3(0, 0.8, 0))), 0.7)   # hochschauen
	handy.visible = false
	aktuelles_versteck = 0
	await _tween(kamera, "global_transform", _versteck_blick(0), 1.3)
	_zeige_verstecken()


# ---------- 2. VERSTECKEN: ums Auto gehen und Ware verteilen ----------

func _zeige_verstecken() -> void:
	# Ist die gewählte Ware schon komplett versteckt, nimm automatisch die nächste.
	if _offen(gewaehlte_ware) == 0:
		for w in WAREN.size():
			if _offen(w) > 0:
				gewaehlte_ware = w
				break

	var v := aktuelles_versteck
	var versteck: Dictionary = VERSTECKE[v]
	var belegt := _summe(versteckt[v])
	var offen := _summe_offen()
	_marker_aus()
	_markiere(v, GELB)
	_neuer_bildschirm(versteck.name, "seite")
	_text("Platz %d/%d  ·  Fund-Chance %d %%\nDrin: %s" % [
		belegt, versteck.kapazitaet, roundi(_fund_chance(v) * 100), _inhalt_text(v)])

	if offen > 0:
		_text("Noch %d Stück zu verstecken:" % offen)
		for w in WAREN.size():
			var knopf := _knopf("%s (%d)" % [WAREN[w].name, _offen(w)], _waehle_ware.bind(w))
			knopf.toggle_mode = true
			knopf.button_pressed = w == gewaehlte_ware
			knopf.disabled = _offen(w) == 0
	else:
		_text("Alles versteckt! Steig ein und fahr zur Grenze.")

	var zeile := _zeile()
	var rein := _knopf("Hier rein", _verstecken.bind(v), zeile)
	rein.disabled = _offen(gewaehlte_ware) == 0 or belegt >= versteck.kapazitaet
	var leeren := _knopf("Leeren", _versteck_leeren.bind(v), zeile)
	leeren.disabled = belegt == 0

	# Von vorne gesehen liegt die rechte Autoseite links von dir – darum +1 nach links.
	zeile = _zeile()
	_knopf("<", _gehe_ums_auto.bind(1), zeile)
	_knopf(">", _gehe_ums_auto.bind(-1), zeile)
	for knopf in zeile.get_children():
		knopf.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var weiter := _knopf("Einsteigen & losfahren", _einsteigen)
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


func _gehe_ums_auto(richtung: int) -> void:
	aktuelles_versteck = posmod(aktuelles_versteck + richtung, VERSTECKE.size())
	_marker_aus()
	_neuer_bildschirm(VERSTECKE[aktuelles_versteck].name, "seite")   # keine Knöpfe, solange du läufst
	await _tween(kamera, "global_transform", _versteck_blick(aktuelles_versteck), 0.9)
	_zeige_verstecken()


func _einsteigen() -> void:
	_marker_aus()
	_karte_weg()
	await _tween(kamera, "global_transform", _fahrer_blick(0.0), 1.5)
	kamera_folgt = true
	finger.clear()
	halte_zeit = 0.0
	verdacht_label.text = "Verdacht: 0 %"
	hinweis_label.text = "Fahr in die Spur mit GRÜNEM Licht und halte mit der Front an der weißen Linie. Tempo %d!" % TEMPOLIMIT
	fahr_hud.visible = true
	faehrt = true


# ---------- 3. FAHREN: selbst zur Maut ----------

func _fahre(delta: float) -> void:
	var gas := _gedrueckt("gas", [KEY_W, KEY_UP])
	var bremse := _gedrueckt("bremse", [KEY_S, KEY_DOWN])
	var rueckwaerts := _gedrueckt("rueck", [KEY_R])
	var lenk_ziel := float(_gedrueckt("links", [KEY_A, KEY_LEFT])) - float(_gedrueckt("rechts", [KEY_D, KEY_RIGHT]))
	lenkung = move_toward(lenkung, lenk_ziel, 3.0 * delta)

	if bremse:
		tempo = move_toward(tempo, 0.0, BREMSKRAFT * delta)
	elif gas:
		tempo = move_toward(tempo, MAX_TEMPO, (BREMSKRAFT if tempo < 0 else BESCHLEUNIGUNG) * delta)
	elif rueckwaerts:
		tempo = move_toward(tempo, -RUECKWAERTS_TEMPO, (BREMSKRAFT if tempo > 0 else BESCHLEUNIGUNG) * delta)
	else:
		tempo = move_toward(tempo, 0.0, ROLLWIDERSTAND * delta)

	# Lenken wirkt nur, wenn das Auto rollt – rückwärts andersrum, wie echt
	auto.rotation.y += lenkung * LENKUNG * clampf(tempo / 5.0, -1.0, 1.0) * delta
	var vorher := auto.position
	auto.position += -auto.basis.z * tempo * delta
	_pruefe_hindernisse(vorher, delta)

	lenkrad.rotation.y = lenkung * 2.0
	tacho.text = "%d km/h" % roundi(absf(tempo) * 3.6)

	if not tempo_geprueft and auto.position.z < MAUT_Z + 30.0:
		tempo_geprueft = true
		if absf(tempo) * 3.6 > TEMPOLIMIT + 5:
			_fahrfehler("zu_schnell")
	_pruefe_anhalten(gas or rueckwaerts, delta)


# Leitplanken, Mauthäuschen und Schranken halten das Auto auf
func _pruefe_hindernisse(vorher: Vector3, delta: float) -> void:
	var p := auto.position
	var neu := ""
	var rand := SPUREN * SPUR_BREITE / 2.0 - AUTO_HALBE_BREITE
	if absf(p.x) >= rand:
		p.x = clampf(p.x, -rand, rand)
		tempo = move_toward(tempo, 0.0, 10.0 * delta)
		neu = "leitplanke"
	for i in SPUREN:
		if absf(p.x - _insel_x(i)) < INSEL_HALBE_BREITE + AUTO_HALBE_BREITE \
				and absf(p.z - MAUT_Z) < INSEL_HALBE_LAENGE + AUTO_HALBE_LAENGE:
			p = vorher
			tempo = 0.0
			neu = "haeuschen"
	if p.z - AUTO_HALBE_LAENGE <= SCHRANKE_Z:
		p.z = SCHRANKE_Z + AUTO_HALBE_LAENGE
		tempo = 0.0
		neu = "schranke"
	p.z = minf(p.z, 15.0)   # nicht rückwärts vom Rastplatz runter
	auto.position = p
	if neu != "" and neu != kontakt:
		_fahrfehler(neu)
	kontakt = neu


# Steht das Auto kurz still an der Maut, wird geprüft, wie gut du angehalten hast
func _pruefe_anhalten(gibt_gas: bool, delta: float) -> void:
	if gibt_gas or absf(tempo) > 0.05 or auto.position.z > MAUT_Z + 4.0:
		halte_zeit = 0.0
		return
	halte_zeit += delta
	if halte_zeit < 0.6 or halte_zeit - delta >= 0.6:   # nur einmal pro Halt
		return
	var spur := clampi(floori((auto.position.x + SPUREN * SPUR_BREITE / 2.0) / SPUR_BREITE), 0, SPUREN - 1)
	if spur != offene_spur:
		if falsche_spur_gemeldet:
			_meldung(FAHRFEHLER.falsche_spur.text)
		else:
			falsche_spur_gemeldet = true
			_fahrfehler("falsche_spur")
		return
	var abstand := absf(auto.position.z - MAUT_Z)
	if abstand > 2.5:
		_fahrfehler("weit_weg")
	elif abstand > 1.0:
		_fahrfehler("ungenau")
	else:
		_meldung("Perfekt angehalten!")
	_zeige_gespraech()


func _fahrfehler(art: String) -> void:
	var fehler: Dictionary = FAHRFEHLER[art]
	verdacht += fehler.verdacht
	verdacht_label.text = "Verdacht: %d %%" % roundi(verdacht * 100)
	_meldung("%s  (+%d %% Verdacht)" % [fehler.text, roundi(fehler.verdacht * 100)])


# Ist ein Fahr-Knopf gerade gedrückt (Finger, Maus oder Taste)?
func _gedrueckt(knopf: String, tasten: Array) -> bool:
	var feld: Control = pedale[knopf]
	var an := false
	for taste in tasten:
		an = an or Input.is_physical_key_pressed(taste)
	for pos in finger.values():
		an = an or feld.get_global_rect().has_point(pos)
	feld.modulate.a = 1.0 if an else 0.55   # gedrückte Knöpfe leuchten auf
	return an


# Normale Knöpfe können nur einen Finger – fürs Fahren merken wir uns alle Finger selbst.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			finger[event.index] = event.position
		else:
			finger.erase(event.index)
	elif event is InputEventScreenDrag:
		finger[event.index] = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			finger[-1] = event.position
		else:
			finger.erase(-1)
	elif event is InputEventMouseMotion and finger.has(-1):
		finger[-1] = event.position


# ---------- 4. MAUT: Ausrede wählen ----------

func _zeige_gespraech() -> void:
	faehrt = false
	tempo = 0.0
	fahr_hud.visible = false
	var fahrer := auto.to_global(SITZ)
	beamter.look_at(Vector3(fahrer.x, beamter.global_position.y, fahrer.z))
	var zum_beamten := auto.to_local(beamter.global_position) - SITZ
	await _tween(self, "kopf_drehung", atan2(-zum_beamten.x, -zum_beamten.z), 0.8)
	_neuer_bildschirm("An der Maut", "unten")
	var frage := "Der Beamte beugt sich zu deinem Fenster:\n\"Guten Tag. Warum wollen Sie ins Nachbarland?\""
	if verdacht > 0:
		frage += "\nEr hat deine Fahrweise gesehen und schaut skeptisch (Verdacht %d %%)." % roundi(verdacht * 100)
	_text(frage)
	var zeile: HBoxContainer
	for a in AUSREDEN.size():
		if a % 2 == 0:
			zeile = _zeile()
		_knopf(AUSREDEN[a].text, _ausrede_gewaehlt.bind(a), zeile).size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ausrede_gewaehlt(a: int) -> void:
	var chance := clampf(AUSREDEN[a].glaubwuerdigkeit - verdacht, MIN_GLAUBWUERDIGKEIT, 1.0)
	_neuer_bildschirm("An der Maut", "unten")
	_text("Du sagst: \"%s\"" % AUSREDEN[a].text)
	if randf() < chance:
		_text("Der Beamte nickt: \"Alles klar. Gute Fahrt!\"")
		_knopf("Weiterfahren", _durchfahren)
	else:
		_text("Der Beamte runzelt die Stirn: \"Das glaube ich Ihnen nicht. Aussteigen – Fahrzeugkontrolle!\"")
		_knopf("Aussteigen", _zeige_durchsuchung)


func _durchfahren() -> void:
	_karte_weg()
	# Im Physik-Takt bewegen: der kommt vor _process, so hängt die Kamera dem Auto nicht hinterher
	var tween := create_tween().set_parallel().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "kopf_drehung", 0.0, 0.8)
	tween.tween_property(schranken[offene_spur], "rotation:z", deg_to_rad(80), 1.2)
	tween.chain().tween_property(auto, "position", Vector3(_spur_mitte(offene_spur), 0, MAUT_Z - 35), 3.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(auto, "rotation:y", 0.0, 1.0)
	await tween.finished
	_runde_beenden(false)


# ---------- 5. DURCHSUCHUNG: der Beamte geht live ums Auto ----------

func _zeige_durchsuchung() -> void:
	_karte_weg()
	kamera_folgt = false
	kopf_drehung = 0.0
	# Du musst aussteigen und vorne rechts warten – von hier siehst du alles
	var stehplatz := auto.to_global(Vector3(4.5, 3.8, -9.5))
	await _tween(kamera, "global_transform", _blick(stehplatz, auto.to_global(Vector3(0, 0.5, 0))), 1.5)
	_neuer_bildschirm("Durchsuchung", "seite")
	_text("Der Beamte geht einmal ums Auto ...")

	# Vom Häuschen zur Fahrertür ...
	var start := _um_das_auto(270.0)
	beamter.look_at(Vector3(start.x, beamter.global_position.y, start.z))
	await _tween(beamter, "global_position", start, 1.2)

	# ... und dann im Uhrzeigersinn an jedem Versteck vorbei
	var reihenfolge := range(VERSTECKE.size())
	reihenfolge.sort_custom(func(a, b): return _weg_bis(a) < _weg_bis(b))
	var winkel := 270.0
	var erwischt := false
	for v in reihenfolge:
		var ziel := 270.0 + _weg_bis(v)
		var tween := create_tween()
		tween.tween_method(_beamter_auf_kreis, winkel, ziel, (ziel - winkel) / 70.0 + 0.2)
		await tween.finished
		winkel = ziel
		beamter.look_at(Vector3(auto.global_position.x, beamter.global_position.y, auto.global_position.z))
		_markiere(v, GELB)
		await get_tree().create_timer(1.0).timeout
		var gefunden := _summe(versteckt[v]) > 0 and randf() < _fund_chance(v)
		erwischt = erwischt or gefunden
		_markiere(v, ROT if gefunden else GRUEN)
		var ergebnis := _text("%s: %s" % [VERSTECKE[v].name, "GEFUNDEN!" if gefunden else "nichts gefunden"])
		ergebnis.add_theme_color_override("font_color", ROT if gefunden else GRUEN)
	_knopf("Weiter", _runde_beenden.bind(erwischt))


# Wie viel Grad der Beamte von der Fahrertür (270°) bis zu diesem Versteck läuft
func _weg_bis(v: int) -> float:
	return fposmod(float(VERSTECKE[v].winkel) - 270.0, 360.0)


func _beamter_auf_kreis(winkel: float) -> void:
	beamter.global_position = _um_das_auto(winkel)
	beamter.look_at(_um_das_auto(winkel + 5.0))


# ---------- 6. ERGEBNIS: verkaufen oder Strafe zahlen ----------

func _runde_beenden(erwischt: bool) -> void:
	var einkauf := _wert("einkauf")
	if erwischt:
		var strafe := _wert("strafe")
		geld = maxi(geld - strafe, 0)
		_neuer_bildschirm("Erwischt!", "mitte")
		_text("Deine Ware (Einkaufswert %d €) wurde beschlagnahmt.\nDazu kommt eine Strafe von %d €." % [einkauf, strafe])
	else:
		var erloes := _wert("verkauf")
		geld += erloes
		_neuer_bildschirm("Durchgekommen!", "mitte")
		_text("Du verkaufst deine Ware für %d €.\nEinkauf: %d €   Gewinn: %d €" % [erloes, einkauf, erloes - einkauf])
	_marker_aus()
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


# Linker Rand von Spur i – genau dort steht ihr Mauthäuschen
func _insel_x(i: int) -> float:
	return -SPUREN * SPUR_BREITE / 2.0 + i * SPUR_BREITE


func _spur_mitte(i: int) -> float:
	return _insel_x(i) + SPUR_BREITE / 2.0


# Findet Tippfehler in den Spieldaten oben schon beim Start (nur beim Testen im Editor aktiv)
func _pruefe_daten() -> void:
	assert(not WAREN.is_empty() and not VERSTECKE.is_empty() and not AUSREDEN.is_empty(), "Jede Liste braucht mindestens einen Eintrag")
	for ware in WAREN:
		assert(ware.has_all(["name", "einkauf", "verkauf", "risiko", "strafe"]), "Ware unvollständig: " + str(ware))
	for versteck in VERSTECKE:
		assert(versteck.has_all(["name", "kapazitaet", "entdeckung", "winkel", "punkt"]), "Versteck unvollständig: " + str(versteck))
	for ausrede in AUSREDEN:
		assert(ausrede.has_all(["text", "glaubwuerdigkeit"]), "Ausrede unvollständig: " + str(ausrede))
	for fehler in FAHRFEHLER.values():
		assert(fehler.has_all(["text", "verdacht"]), "Fahrfehler unvollständig: " + str(fehler))
	assert(SPUREN >= 1, "Es braucht mindestens eine Mautspur")


# =====================================================================
#  KAMERA & ANIMATION
# =====================================================================

# Eine Kamera-Stellung: steht bei "von" und schaut auf "nach"
func _blick(von: Vector3, nach: Vector3) -> Transform3D:
	return Transform3D(Basis(), von).looking_at(nach)


func _fahrer_blick(kopf: float) -> Transform3D:
	return auto.global_transform * Transform3D(Basis.from_euler(Vector3(-0.12, kopf, 0)), SITZ)


# Vor einem Versteck stehen und draufschauen
func _versteck_blick(v: int) -> Transform3D:
	var w := deg_to_rad(VERSTECKE[v].winkel)
	return _blick(auto.to_global(Vector3(sin(w) * 4.0, 1.7, -cos(w) * 4.0)), auto.to_global(VERSTECKE[v].punkt))


# Ein Punkt auf dem Weg des Beamten ums Auto (Oval, damit er nicht durchs Auto läuft)
func _um_das_auto(winkel: float) -> Vector3:
	var w := deg_to_rad(winkel)
	return auto.to_global(Vector3(sin(w) * 1.5, 0, -cos(w) * 3.0))


# Bewegt eine Eigenschaft weich zum Zielwert. Mit "await" wartet man, bis es fertig ist.
func _tween(objekt: Object, eigenschaft: String, ziel: Variant, dauer: float) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(objekt, eigenschaft, ziel, dauer)
	await tween.finished


func _markiere(v: int, farbe: Color) -> void:
	marker[v].visible = true
	_faerbe(marker[v], farbe, true)


func _marker_aus() -> void:
	for punkt in marker:
		punkt.visible = false


func _faerbe(teil: MeshInstance3D, farbe: Color, leuchtet := false) -> void:
	var material: StandardMaterial3D = teil.material_override
	material.albedo_color = farbe
	material.emission_enabled = leuchtet
	material.emission = farbe


# =====================================================================
#  3D-WELT – alles aus einfachen Formen per Code gebaut
# =====================================================================

func _baue_welt() -> void:
	var umgebung := Environment.new()
	umgebung.background_mode = Environment.BG_SKY
	umgebung.sky = Sky.new()
	umgebung.sky.sky_material = ProceduralSkyMaterial.new()
	umgebung.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var welt := WorldEnvironment.new()
	welt.environment = umgebung
	add_child(welt)

	var sonne := DirectionalLight3D.new()
	sonne.rotation_degrees = Vector3(-55, 35, 0)
	sonne.shadow_enabled = true
	add_child(sonne)

	kamera = Camera3D.new()
	kamera.fov = 70
	kamera.near = 0.03   # damit das Handy in der Hand nicht abgeschnitten wird
	add_child(kamera)
	kamera.make_current()

	_baue_strasse()
	_baue_maut()
	_baue_auto()
	_baue_beamter()
	_baue_handy()


func _baue_strasse() -> void:
	var breite := SPUREN * SPUR_BREITE
	var anfang := 20.0
	var ende := MAUT_Z - 60.0
	var mitte := (anfang + ende) / 2.0
	var laenge := anfang - ende
	_klotz(Vector3(600, 0.1, 600), Vector3(0, -0.06, mitte), Color("5b8c3a"))   # Wiese
	_klotz(Vector3(breite + 2, 0.02, laenge), Vector3(0, 0, mitte), Color("3b3e44"))   # Asphalt
	for seite in [-1, 1]:
		_klotz(Vector3(0.25, 0.5, laenge), Vector3(seite * (breite / 2 + 0.8), 0.35, mitte), Color("9aa0a6"))   # Leitplanke
		_klotz(Vector3(0.15, 0.02, laenge), Vector3(seite * (breite / 2 - 0.1), 0.012, mitte), Color.WHITE)   # Randlinie
	# Gestrichelte Linien zwischen den Spuren, bis kurz vor die Maut
	for i in range(1, SPUREN):
		var z := anfang
		while z > MAUT_Z + 10:
			_klotz(Vector3(0.15, 0.02, 3), Vector3(_insel_x(i), 0.012, z), Color.WHITE)
			z -= 8.0

	# Schild am Rastplatz und Tempo-Schild vor der Maut
	var rechts := breite / 2 + 2.5
	_klotz(Vector3(0.1, 2.0, 0.1), Vector3(rechts, 1.0, -12), Color("888888"))
	_klotz(Vector3(3.0, 1.4, 0.1), Vector3(rechts, 2.6, -12), Color("1d4e89"))
	_schrift("Grenze\nMaut %d m" % int(MAUT_ENTFERNUNG), Vector3(rechts, 2.6, -11.94), 0.45, Color.WHITE)
	_klotz(Vector3(0.1, 2.2, 0.1), Vector3(rechts, 1.1, MAUT_Z + 50), Color("888888"))
	var scheibe := CylinderMesh.new()
	scheibe.top_radius = 0.5
	scheibe.bottom_radius = 0.5
	scheibe.height = 0.04
	_mesh(scheibe, Vector3(rechts, 2.6, MAUT_Z + 50), ROT).rotation.x = PI / 2
	_mesh(scheibe, Vector3(rechts, 2.6, MAUT_Z + 50.03), Color.WHITE).scale = Vector3(0.78, 1, 0.78)
	_schrift(str(TEMPOLIMIT), Vector3(rechts, 2.6, MAUT_Z + 50.06), 0.5, Color.BLACK)

	# Bäume, damit man sieht, wie schnell man ist
	var zufall := RandomNumberGenerator.new()
	zufall.seed = 42   # immer dieselben Bäume
	var stamm := CylinderMesh.new()
	stamm.top_radius = 0.15
	stamm.bottom_radius = 0.2
	stamm.height = 2.0
	var krone := CylinderMesh.new()
	krone.top_radius = 0.0
	krone.bottom_radius = 1.5
	krone.height = 4.0
	for n in 70:
		var x := (breite / 2 + zufall.randf_range(4.0, 50.0)) * (1 if n % 2 else -1)
		var pos := Vector3(x, 0, zufall.randf_range(MAUT_Z - 50, 40))
		_mesh(stamm, pos + Vector3(0, 1.0, 0), Color("6b4f2a"))
		_mesh(krone, pos + Vector3(0, 3.8, 0), Color("2d6a2e"))


func _baue_maut() -> void:
	var breite := SPUREN * SPUR_BREITE
	var arm_laenge := SPUR_BREITE - 2 * INSEL_HALBE_BREITE - 0.1
	for i in SPUREN:
		var x := _insel_x(i)
		_klotz(Vector3(INSEL_HALBE_BREITE * 2, 0.15, INSEL_HALBE_LAENGE * 2), Vector3(x, 0.075, MAUT_Z), Color("c8c8c8"))   # Verkehrsinsel
		_klotz(Vector3(1.0, 2.4, 2.5), Vector3(x, 1.35, MAUT_Z + 1.75), Color("ece6d6"))   # Mauthäuschen
		_klotz(Vector3(1.04, 0.9, 1.8), Vector3(x, 1.75, MAUT_Z + 1.75), Color("8ecae6"))   # Fenster
		_klotz(Vector3(0.3, 5.4, 0.3), Vector3(x, 2.7, MAUT_Z - 3.0), Color("9aa0a6"))   # Dachstütze
		# Haltelinie: hier soll die Front deines Autos stehen
		_klotz(Vector3(SPUR_BREITE - 1.4, 0.02, 0.35), Vector3(_spur_mitte(i), 0.014, MAUT_Z - AUTO_HALBE_LAENGE), Color.WHITE)
		# Schranke – dreht sich zum Öffnen um ihr linkes Ende
		var schranke := Node3D.new()
		schranke.position = Vector3(x + INSEL_HALBE_BREITE, 1.0, SCHRANKE_Z)
		add_child(schranke)
		for s in 6:
			_klotz(Vector3(arm_laenge / 6, 0.12, 0.12), Vector3((s + 0.5) * arm_laenge / 6, 0, 0),
				Color("d62828") if s % 2 == 0 else Color.WHITE, schranke)
		schranken.append(schranke)
		ampeln.append(_klotz(Vector3(0.9, 0.9, 0.15), Vector3(_spur_mitte(i), 4.6, MAUT_Z + 4.9), ROT))   # Ampel über der Spur
	_klotz(Vector3(0.3, 5.4, 0.3), Vector3(breite / 2, 2.7, MAUT_Z - 3.0), Color("9aa0a6"))   # rechte Dachstütze
	_klotz(Vector3(breite + 2, 0.5, 10), Vector3(0, 5.6, MAUT_Z), Color("f1faee"))   # Dach
	_schrift("MAUT  ·  GRENZE", Vector3(0, 5.6, MAUT_Z + 5.06), 0.45, Color("1d3557"))


func _baue_auto() -> void:
	auto = Node3D.new()
	add_child(auto)
	var lack := Color("c1121f")
	_klotz(Vector3(1.8, 0.6, 4.2), Vector3(0, 0.6, 0), lack, auto)   # Karosserie
	# Die Scheiben sind ein Kasten, den man von innen nicht sieht (Godot zeigt nur Außenseiten) – perfekt zum Rausschauen
	_klotz(Vector3(1.6, 0.6, 2.2), Vector3(0, 1.2, 0.3), Color("2b3a4a"), auto)
	_klotz(Vector3(1.7, 0.08, 2.0), Vector3(0, 1.54, 0.4), lack, auto)   # Dach
	var reifen := CylinderMesh.new()
	reifen.top_radius = 0.35
	reifen.bottom_radius = 0.35
	reifen.height = 0.25
	for seite in [-1, 1]:
		_klotz(Vector3(0.08, 0.64, 0.08), Vector3(seite * 0.78, 1.2, -0.76), lack, auto)   # Fenstersäule vorne
		_klotz(Vector3(0.3, 0.12, 0.05), Vector3(seite * 0.6, 0.7, -2.11), Color("fff3b0"), auto)   # Scheinwerfer
		for z in [-1.35, 1.35]:
			_mesh(reifen, Vector3(seite * 0.85, 0.35, z), Color("1a1a1a"), auto).rotation.z = PI / 2

	# Innenraum
	_klotz(Vector3(1.6, 0.2, 0.4), Vector3(0, 0.88, -0.65), Color("2a2a2a"), auto)   # Armaturenbrett
	var halter := Node3D.new()   # hält das Lenkrad schräg zum Fahrer
	halter.position = Vector3(SITZ.x, 0.9, -0.3)
	halter.rotation.x = deg_to_rad(70)
	auto.add_child(halter)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.15
	ring.outer_radius = 0.18
	lenkrad = _mesh(ring, Vector3.ZERO, Color("111111"), halter)
	_klotz(Vector3(0.32, 0.03, 0.05), Vector3.ZERO, Color("333333"), lenkrad)   # Speiche, damit man das Drehen sieht
	tacho = _schrift("0 km/h", Vector3(0.1, 0.94, -0.44), 0.06, Color("90ee90"), auto)

	# Leuchtpunkte an den Verstecken – sieht man auch durchs Auto hindurch
	var kugel := SphereMesh.new()
	kugel.radius = 0.13
	kugel.height = 0.26
	for versteck in VERSTECKE:
		var punkt := _mesh(kugel, versteck.punkt, GELB, auto)
		var material: StandardMaterial3D = punkt.material_override
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		marker.append(punkt)


func _baue_beamter() -> void:
	beamter = Node3D.new()
	add_child(beamter)
	var uniform := Color("1d3557")
	_klotz(Vector3(0.36, 0.8, 0.24), Vector3(0, 0.4, 0), Color("14213d"), beamter)   # Beine
	var koerper := CapsuleMesh.new()
	koerper.radius = 0.24
	koerper.height = 0.9
	_mesh(koerper, Vector3(0, 1.15, 0), uniform, beamter)
	var kopf := SphereMesh.new()
	kopf.radius = 0.14
	kopf.height = 0.28
	_mesh(kopf, Vector3(0, 1.75, 0), Color("e0ac69"), beamter)
	var muetze := CylinderMesh.new()
	muetze.top_radius = 0.16
	muetze.bottom_radius = 0.15
	muetze.height = 0.1
	_mesh(muetze, Vector3(0, 1.88, 0), uniform, beamter)
	_klotz(Vector3(0.24, 0.02, 0.14), Vector3(0, 1.84, -0.18), Color("111111"), beamter)   # Mützenschirm = vorne


func _baue_handy() -> void:
	handy = Node3D.new()
	add_child(handy)
	_klotz(Vector3(0.075, 0.15, 0.01), Vector3.ZERO, Color("111111"), handy)
	var bildschirm := _klotz(Vector3(0.065, 0.135, 0.002), Vector3(0, 0, -0.006), Color("4cc9f0"), handy)
	_faerbe(bildschirm, Color("4cc9f0"), true)
	_klotz(Vector3(0.09, 0.05, 0.05), Vector3(0, -0.08, 0.02), Color("e0ac69"), handy)   # Hand


# Ein Quader in einer Farbe
func _klotz(groesse: Vector3, pos: Vector3, farbe: Color, eltern: Node = null) -> MeshInstance3D:
	var kasten := BoxMesh.new()
	kasten.size = groesse
	return _mesh(kasten, pos, farbe, eltern)


# Eine beliebige Form in einer Farbe (jedes Teil bekommt eine eigene Farbe, damit man es umfärben kann)
func _mesh(form: Mesh, pos: Vector3, farbe: Color, eltern: Node = null) -> MeshInstance3D:
	if eltern == null:
		eltern = self
	var teil := MeshInstance3D.new()
	teil.mesh = form
	teil.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = farbe
	teil.material_override = material
	eltern.add_child(teil)
	return teil


# Schrift in der 3D-Welt, "hoehe" in Metern
func _schrift(text: String, pos: Vector3, hoehe: float, farbe: Color, eltern: Node = null) -> Label3D:
	if eltern == null:
		eltern = self
	var schrift := Label3D.new()
	schrift.text = text
	schrift.font_size = 100
	schrift.pixel_size = hoehe / 100.0
	schrift.outline_size = 0
	schrift.modulate = farbe
	schrift.position = pos
	eltern.add_child(schrift)
	return schrift


# =====================================================================
#  OBERFLÄCHE – alles per Code gebaut
# =====================================================================

func _baue_oberflaeche() -> void:
	# Spiel automatisch auf jede Bildschirmgröße skalieren
	var fenster := get_window()
	fenster.content_scale_size = BASIS_AUFLOESUNG
	fenster.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	fenster.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

	var ebene := CanvasLayer.new()   # liegt über der 3D-Welt
	add_child(ebene)
	var wurzel := Control.new()
	wurzel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wurzel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wurzel.theme = Theme.new()
	wurzel.theme.default_font_size = SCHRIFT_GROESSE   # gilt für alle Texte und Knöpfe
	ebene.add_child(wurzel)

	# Die Infokarte: Handy, Seitenleiste, Dialog unten oder Ergebnis in der Mitte
	karten_stil = StyleBoxFlat.new()
	karten_stil.bg_color = Color(0.11, 0.15, 0.2, 0.93)
	karten_stil.set_corner_radius_all(18)
	karten_stil.set_content_margin_all(16)
	handy_stil = karten_stil.duplicate()
	handy_stil.set_border_width_all(14)
	handy_stil.border_color = Color("0b0b0b")
	handy_stil.set_corner_radius_all(44)
	handy_stil.set_content_margin_all(30)
	karte = PanelContainer.new()
	wurzel.add_child(karte)

	var spalte := VBoxContainer.new()
	spalte.add_theme_constant_override("separation", 8)
	karte.add_child(spalte)

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

	# Anzeigen und Knöpfe fürs Fahren
	fahr_hud = Control.new()
	fahr_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fahr_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fahr_hud.visible = false
	wurzel.add_child(fahr_hud)
	hinweis_label = _hud_text(fahr_hud, Color.WHITE, [0, 0, 1, 0, 340, 12, -340, 100])
	hinweis_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verdacht_label = _hud_text(fahr_hud, ROT, [1, 0, 1, 0, -330, 12, -16, 50])
	verdacht_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pedal("links", "<", Color("457b9d"), [0, 1, 0, 1, 24, -184, 184, -24])
	_pedal("rechts", ">", Color("457b9d"), [0, 1, 0, 1, 200, -184, 360, -24])
	_pedal("rueck", "R", Color("6c757d"), [1, 1, 1, 1, -556, -144, -440, -24])
	_pedal("bremse", "BREMSE", Color("c1121f"), [1, 1, 1, 1, -424, -184, -244, -24])
	_pedal("gas", "GAS", Color("2a9d8f"), [1, 1, 1, 1, -228, -244, -24, -24])

	status_label = _hud_text(wurzel, GELB, [0, 0, 0, 0, 16, 12, 600, 50])
	meldung_label = _hud_text(wurzel, GELB, [0, 0, 1, 0, 100, 110, -100, 200])
	meldung_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meldung_label.add_theme_font_size_override("font_size", TITEL_GROESSE)


# Setzt Anker und Abstände eines Elements (Aufbau wie bei KARTEN oben)
func _platziere(element: Control, werte: Array) -> void:
	for seite in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		element.set_anchor_and_offset(seite, werte[seite], werte[seite + 4], true)


# Text direkt über der 3D-Welt – mit schwarzem Rand, damit man ihn überall lesen kann
func _hud_text(eltern: Control, farbe: Color, platz: Array) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", farbe)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eltern.add_child(label)
	_platziere(label, platz)
	return label


# Ein Fahr-Knopf. Er reagiert über _input, damit mehrere Finger gleichzeitig gehen.
func _pedal(name: String, text: String, farbe: Color, platz: Array) -> void:
	var feld := Label.new()
	feld.text = text
	feld.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feld.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var stil := StyleBoxFlat.new()
	stil.bg_color = farbe
	stil.set_corner_radius_all(24)
	feld.add_theme_stylebox_override("normal", stil)
	feld.modulate.a = 0.55
	fahr_hud.add_child(feld)
	_platziere(feld, platz)
	pedale[name] = feld


# Kurze Meldung in der Bildschirmmitte, die nach ein paar Sekunden verschwindet
func _meldung(text: String) -> void:
	meldung_label.text = text
	meldung_label.modulate.a = 1.0
	if meldung_tween:
		meldung_tween.kill()
	meldung_tween = create_tween()
	meldung_tween.tween_interval(2.0)
	meldung_tween.tween_property(meldung_label, "modulate:a", 0.0, 0.8)


# Leert die Infokarte, stellt sie an die passende Stelle ("art" aus KARTEN) und aktualisiert Geld/Runde
func _neuer_bildschirm(titel: String, art: String) -> void:
	titel_label.text = titel
	status_label.text = "Geld: %d €   ·   Runde %d" % [geld, runde]
	_platziere(karte, KARTEN[art])
	karte.add_theme_stylebox_override("panel", handy_stil if art == "handy" else karten_stil)
	karte.visible = true
	for kind in inhalt.get_children():
		kind.queue_free()


func _karte_weg() -> void:
	karte.visible = false


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
