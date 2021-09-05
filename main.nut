require("version.nut");

class MainClass extends GSController 
{
	savedata = {}

	constructor()
	{
	}
}

function EternalLove()
{
	local towns = GSTownList();
	for (local t = towns.Begin(); !towns.IsEnd(); t = towns.Next()) {
		// And all companies
		for (local c = GSCompany.COMPANY_FIRST; c <= GSCompany.COMPANY_LAST; c++) {
			if (!GSTown.IsValidTown(t)) break; // skip if town has disappeared
			if (GSCompany.ResolveCompanyID(c) != c) continue; // skip non-existing companies
			local cur_rating_class = GSTown.GetRating(t, c);
			// Check if rating needs to be changed
			if (cur_rating_class == GSTown.TOWN_RATING_NONE) continue;
			if (cur_rating_class == GSTown.TOWN_RATING_INVALID) continue;
			if (cur_rating_class == GSTown.TOWN_RATING_OUTSTANDING) continue;
			// It does, boost to max
			GSTown.ChangeRating(t, c, 2000);
		}
	}
}

function IsDigit(s) {
	return s == "0"
		|| s == "1"
		|| s == "2"
		|| s == "3"
		|| s == "4"
		|| s == "5"
		|| s == "6"
		|| s == "7"
		|| s == "8"
		|| s == "9";
}

function CollectEventSequence()
{
	local signs = GSSignList();
	local events = [];
	for (local s = signs.Begin(); !signs.IsEnd(); s = signs.Next()) {
		local e = {
			sign_id = s
			tile = GSSign.GetLocation(s)
			owner = GSSign.GetOwner(s)
			valid = false
			seq_num = null
			halign = "C"
			valign = "M"
			pan = false
			follow_vehicle = null
			zoom = ""
			delay = null
		}
		local text = GSSign.GetName(s).toupper();
		GSLog.Info("Parsing sign " + s + ": " + text);
		if (text.slice(0, 1) == "T") {
			local p = 2;
			// skip space after leading T
			while (p < text.len() && text.slice(p, p+1) == " ") p++;
			if (p >= text.len() || !IsDigit(text.slice(p, p+1))) continue; // reject missing sequence number
			// read sequence number
			e.seq_num = 0;
			while (p < text.len() && IsDigit(text.slice(p, p+1))) {
				e.seq_num = e.seq_num * 10 + text.slice(p, p+1).tointeger();
				p++;
			}
			GSLog.Info("  Sequence number ok: " + e.seq_num);
			// skip space after sequence number
			while (p < text.len() && text.slice(p, p+1) == " ") p++;
			// read command
			local c;
			while (p < text.len() && text.slice(p, p+1) != " ") {
				c = text.slice(p, p+1);
				p++;
				if (c == "T" || c == "M" || c == "B") {
					// read alignment
					e.valign = c;
					GSLog.Info("  Vertical alignment " + e.valign);
				} else if (c == "L" || c == "C" || c == "R") {
					// read alignment
					e.halign = c;
					GSLog.Info("  Horizontal alignment " + e.halign);
				} else if (c == "P") {
					// read pan flag
					e.pan = true;
					GSLog.Info("  Pan flag set");
				} else if (c == "+") {
					// read zoom flag
					e.zoom = "+";
					GSLog.Info("  Zoom flag plus");
				} else if (c == "-") {
					// read zoom flag
					e.zoom = "-";
					GSLog.Info("  Zoom flag minus");
				} else if (c == "V") {
					// read vehicle id
					e.follow_vehicle = 0;
					while (p < text.len() && IsDigit(text.slice(p, p+1))) {
						e.follow_vehicle = e.follow_vehicle * 10 + text.slice(p, p+1).tointeger();
						p++;
					}
					GSLog.Info("  Follow vehicle " + e.follow_vehicle);
				}
			}
			// skip space after command
			while (p < text.len() && text.slice(p, p+1) == " ") p++;
			if (p >= text.len() || !IsDigit(text.slice(p, p+1))) continue; // reject missing delay
			// read delay
			e.delay = 0
			while (p < text.len() && IsDigit(text.slice(p, p+1))) {
				e.delay = e.delay * 10 + text.slice(p, p+1).tointeger();
				p++;
			}
			GSLog.Info("  Delay ok: " + e.delay);
			// success!
			e.valid = true;
			events.push(e);
			GSLog.Info("  Event added!");
		}
	}

	return events;
}

function CollectAllCompanyEventSequence()
{
	local events = CollectEventSequence();
	for (local c = GSCompany.COMPANY_FIRST; c <= GSCompany.COMPANY_LAST; c++) {
		local mode = GSCompanyMode(c);
		events.extend(CollectEventSequence());
	}
	events.sort(function(a, b) { return a.seq_num - b.seq_num; });
	return events;
}

function MakeEventSequenceGoals(events)
{
	local new_goal_ids = [];

	foreach (e in events) {
		local text = "(" + e.seq_num + ") ";

		if (e.follow_vehicle) {
			if (GSVehicle.IsValidVehicle(e.follow_vehicle)) {
				text += "Follow " + GSVehicle.GetName(e.follow_vehicle);
			} else {
				text += "Follow vehicle #" + e.follow_vehicle + " (invalid ID)";
			}
		} else {
			text += "Position at (" + GSMap.GetTileX(e.tile) + ", " + GSMap.GetTileY(e.tile) + ")";
		}

		text += " aligned ";
		if (e.halign == "C" && e.valign == "M") {
			text += "center";
		} else {
			if (e.valign = "T") {
				text += "top-";
			} else if (e.valign = "M") {
				text += "middle-";
			} else if (e.valign = "B") {
				text += "bottom-";
			}
			if (e.halign == "L") {
				text += "left";
			} else if (e.halign == "C") {
				text += "center";
			} else if (e.halign == "R") {
				text += "right";
			}
		}

		text += " for " + e.delay + " second" + (e.delay == 1 ? "" : "s");

		if (e.zoom == "+") {
			text += ", zoomed in";
		} else if (e.zoom == "-") {
			text += ", zoomed out";
		}

		if (e.pan) {
			text += ", and pan to next"
		}

		new_goal_ids.push(GSGoal.New(GSCompany.COMPANY_INVALID, text, GSGoal.GT_TILE, e.tile));
	}

	return new_goal_ids;
}


function RenumberEventSequence(events)
{
	local next_seq_num = 10;
	foreach (e in events) {
		local company_mode;
		if (e.owner != GSCompany.COMPANY_INVALID) company_mode = GSCompanyMode(e.owner);
		e.seq_num = next_seq_num;
		next_seq_num += 10;

		local align = (e.halign != "C" ? e.halign : "") + (e.valign != "M" ? e.valign : "");
		if (align == "") align = "C";
		local new_text = "T " + e.seq_num + " " + align + e.zoom + (e.pan ? "P" : "") + (e.follow_vehicle ? "V" + e.follow_vehicle : "") + " " + e.delay;
		GSSign.SetName(e.sign_id, new_text);
	}
}


STORYBOOK_VER <- 1;

function UpdateStorybook(savedata)
{
	// Check if storybook is already correct version
	if ("storybook_ver" in savedata && savedata.storybook_ver != STORYBOOK_VER) return;

	// Remove all existing pages
	if ("page_id_formathelp" in savedata) GSStoryPage.Remove(savedata.page_id_formathelp);
	if ("page_id_sequence" in savedata) GSStoryPage.Remove(savedata.page_id_sequence);
	if ("page_id_vehinfo" in savedata) GSStoryPage.Remove(savedata.page_id_vehinfo);

	// Update version info
	savedata.storybook_ver <- STORYBOOK_VER;

	// Make command format help page in storybook
	savedata.page_id_formathelp <- GSStoryPage.New(GSCompany.COMPANY_FIRST, "Signs format");
	GSStoryPage.NewElement(savedata.page_id_formathelp, GSStoryPage.SPET_TEXT, 0, "You can control how the view of the intro game (behind the game's main menu) moves by putting signs around the map with commands.");
	GSStoryPage.NewElement(savedata.page_id_formathelp, GSStoryPage.SPET_TEXT, 0, "These command signs all start with a T, then a sequence-number, then some positioning flag, and finally how many seconds to stay at that position. Here's an example:");
	GSStoryPage.NewElement(savedata.page_id_formathelp, GSStoryPage.SPET_BUTTON_PUSH, GSStoryPage.SPBC_BROWN, "T 2 C- 15");
	GSStoryPage.NewElement(savedata.page_id_formathelp, GSStoryPage.SPET_TEXT, 0, "The above command is sequence number 2. It centers the screen on the sign for 15 seconds, and zooms out.");
	GSStoryPage.NewElement(savedata.page_id_formathelp, GSStoryPage.SPET_TEXT, 0, "The sequence number controls which order the commands are performed in. Sequence number 2 always happens before sequence number 8, regardless of where or when the signs with them were placed. This storybook has some tools to help you keep track of the sequence numbers.");
	GSStoryPage.NewElement(savedata.page_id_formathelp, GSStoryPage.SPET_TEXT, 0, "The placement of the command signs matters: The position of the sign is also where the screen is positioned! You can control the positioning with the alignment flags: T = Top, M = Middle (vertical centre), B = Bottom, L = Left, C = Centre (horizontal), R = Right");
	GSStoryPage.NewElement(savedata.page_id_formathelp, GSStoryPage.SPET_TEXT, 0, "You can also control the zoom level, by putting a + or a - in the positioning flags.");
	GSStoryPage.NewElement(savedata.page_id_formathelp, GSStoryPage.SPET_TEXT, 0, "If you put a P in the positioning flags, then instead of standing still, the camera will pan from this sign over to the next sign. This lets you make movement and show more of the map.");
	GSStoryPage.NewElement(savedata.page_id_formathelp, GSStoryPage.SPET_TEXT, 0, "Lastly, you can put a V, followed by a vehicle ID, to make the camera follow a specific vehicle around. This is another way to make movement. This storybook has a tool to get vehicle info, including the vehicle ID.");
	GSStoryPage.NewElement(savedata.page_id_formathelp, GSStoryPage.SPET_TEXT, 0, "Signs that don't follow the format are ignored, and don't get used for camera control.");

	// Make sequence management storybook page
	savedata.page_id_sequence <- GSStoryPage.New(GSCompany.COMPANY_FIRST, "View sequence");
	savedata.button_id_sequence_show <- GSStoryPage.NewElement(savedata.page_id_sequence, GSStoryPage.SPET_BUTTON_PUSH,
		GSStoryPage.MakePushButtonReference(GSStoryPage.SPBC_LIGHT_BLUE, GSStoryPage.SPBF_NONE),
		"Show event sequence");
	GSStoryPage.NewElement(savedata.page_id_sequence, GSStoryPage.SPET_TEXT, 0, "Read the entire event sequence of positions to show, and show in the goal list what will happen.");
	savedata.button_id_sequence_renumber <- GSStoryPage.NewElement(savedata.page_id_sequence, GSStoryPage.SPET_BUTTON_PUSH,
		GSStoryPage.MakePushButtonReference(GSStoryPage.SPBC_LIGHT_BLUE, GSStoryPage.SPBF_NONE),
		"Renumber all events");
	GSStoryPage.NewElement(savedata.page_id_sequence, GSStoryPage.SPET_TEXT, 0, "Re-generate the event numbers on all event signs, such that the sequence increases by 10 for each. This makes room to insert new events between existing ones.");

	// Make vehicle info storybook page
	savedata.page_id_vehinfo <- GSStoryPage.New(GSCompany.COMPANY_FIRST, "Vehicle info");
	savedata.button_id_vehinfo_select <- GSStoryPage.NewElement(savedata.page_id_vehinfo, GSStoryPage.SPET_BUTTON_VEHICLE,
		GSStoryPage.MakeVehicleButtonReference(GSStoryPage.SPBC_LIGHT_BLUE, GSStoryPage.SPBF_NONE, GSStoryPage.SPBC_QUERY, GSVehicle.VT_INVALID),
		"Select vehicle");
	GSStoryPage.NewElement(savedata.page_id_vehinfo, GSStoryPage.SPET_TEXT, 0, "Click the above button, then click a vehicle on the map, to get information on that vehicle.");
	savedata.line_id_vehinfo_name <- GSStoryPage.NewElement(savedata.page_id_vehinfo, GSStoryPage.SPET_TEXT, 0, "Vehicle name");
	savedata.line_id_vehinfo_idthis <- GSStoryPage.NewElement(savedata.page_id_vehinfo, GSStoryPage.SPET_TEXT, 0, "Vehicle ID clicked");
}


function MainClass::Start()
{
	GSController.Sleep(1);
	local last_townreset_tick = 0;

	UpdateStorybook(savedata);

	while (true) {
		local loop_start_tick = GSController.GetTick();

		// Eat all events
		while (GSEventController.IsEventWaiting()) {
			local ev = GSEventController.GetNextEvent();

			if (ev.GetEventType() == GSEvent.ET_STORYPAGE_VEHICLE_SELECT) {
				ev = GSEventStoryPageVehicleSelect.Convert(ev);
				if (ev.GetElementID() == savedata.button_id_vehinfo_select) {
					// Select vehicle to show info
					local veh_id = ev.GetVehicleID();
					GSStoryPage.UpdateElement(savedata.line_id_vehinfo_name, 0, "Vehicle name: " + GSVehicle.GetName(veh_id));
					GSStoryPage.UpdateElement(savedata.line_id_vehinfo_idthis, 0, "Vehicle ID clicked: " + veh_id);
				}
			} else if (ev.GetEventType() == GSEvent.ET_STORYPAGE_BUTTON_CLICK) {
				ev = GSEventStoryPageButtonClick.Convert(ev);
				if (ev.GetElementID() == savedata.button_id_sequence_show) {
					// Generate goal list of events in sequence
					local events = CollectAllCompanyEventSequence();
					if ("goal_ids" in savedata) {
						foreach (goal_id in savedata.goal_ids) GSGoal.Remove(goal_id);
						delete savedata.goal_ids;
					}
					local new_goal_ids = MakeEventSequenceGoals(events);
					if (new_goal_ids) savedata.goal_ids <- new_goal_ids;
				} else if (ev.GetElementID() == savedata.button_id_sequence_renumber) {
					// Renumber all events to new sequence
					local events = CollectAllCompanyEventSequence();
					RenumberEventSequence(events);
				}
			}
		}

		// Go over all towns once every week, reset company ratings
		if (loop_start_tick - last_townreset_tick > 74*7) {
			EternalLove();
			last_townreset_tick = GSController.GetTick();
		}
	}
}

function MainClass::Save()
{
	return savedata;
}

function MainClass::Load(version, tbl)
{
	savedata = tbl;
}
