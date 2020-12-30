const float COUNTER_GUI_DISTANCE_FROM_RIGHT = 0.0f;
const float COUNTER_GUI_DISTANCE_FROM_BOTTOM = 400.0f;
const float COUNTER_GUI_LEFT_RIGHT_MARGIN = 50.0f;
const float COUNTER_GUI_TOP_BOTTOM_MARGIN = 10.0f;

const float COUNTER_GUI_RABBIT_STATUE_HEIGHT = 100.0f;

const float COUNTER_SLIDE_DURATION = 0.5f;
const float COUNTER_DURATION = 5.0f;

const int AMOUNT_RABBIT_STATUE_ANIMATION_FRAMES = 36;

IMGUI@ gui;
IMImage@ preview_fade_image;

IMText@ congratulations_text;
IMText@ time_taken_text;
IMText@ time_taken_text2;
IMText@ resets_amount_text;
IMText@ resets_amount_text2;

IMContainer@ counter_container;
IMImage@ counter_background_image;
IMImage@ rabbit_statue_image;
IMText@ level_progress_text;

float counter_slide_timestamp;
float counter_timestamp;

enum GuiCounterState {
	GCS_HIDDEN = 0,
	GCS_SLIDING_IN = 1,
	GCS_SHOWING = 2,
	GCS_SLIDING_OUT = 3
}

void SetStatisticsVisibility(bool show)
{
	congratulations_text.setVisible(show);
	
	time_taken_text.setVisible(show);
	time_taken_text2.setVisible(show);
	
	resets_amount_text.setVisible(show);
	resets_amount_text2.setVisible(show);
}

void SetStatistics(float time, int retries)
{
	int minutes = 0;
	if (time >= 60) minutes = int(time) / 60;
	
	int seconds = int(time) - minutes * 60;
	
	string timestring = "";
	if (minutes > 0) timestring += minutes + "m ";
	
	if (seconds > 0) timestring += seconds + "s";
	
	// Fallback check just for safety (if the script resets on a statue)
	if (time < 1) timestring = "0s";
	
	time_taken_text2.setText(timestring);
	resets_amount_text2.setText(retries + "");
	
	gui.update();
}

void GcsSlidingIn(bool state_changed)
{
	if (state_changed)
	{
		counter_slide_timestamp = ImGui_GetTime();
		
		counter_container.setVisible(true);
		for (uint i = 0; i < counter_container.getFloatingContents().length(); i++)
			counter_container.getFloatingContents()[i].setVisible(true);
	}

	RefreshRabbitGuiAnimation();

	if (ImGui_GetTime() - counter_slide_timestamp <= COUNTER_SLIDE_DURATION)
	{
		float percentage = (ImGui_GetTime() - counter_slide_timestamp) / COUNTER_SLIDE_DURATION;
		
		// We are using 1.001 the length of the GUI because if we only use 1.0
		// then the counter gui might leave a gap between itself and the window frame.
		
		gui.getMain().moveElement(
			counter_container.getName(),
			vec2(
				1.001f * gui.getMain().getSizeX() - (counter_container.getSizeX() - COUNTER_GUI_DISTANCE_FROM_RIGHT) * percentage,
				gui.getMain().getSizeY() - counter_container.getSizeY() - COUNTER_GUI_DISTANCE_FROM_BOTTOM
			)
		);
	}
	else
	{
		gui.getMain().moveElement(
			counter_container.getName(),
			vec2(
				1.001f * gui.getMain().getSizeX() - (counter_container.getSizeX() - COUNTER_GUI_DISTANCE_FROM_RIGHT),
				gui.getMain().getSizeY() - counter_container.getSizeY() - COUNTER_GUI_DISTANCE_FROM_BOTTOM
			)
		);

		current_counter_state = GCS_SHOWING;
		Log(fatal, "GCS_SLIDING_IN -> GCS_SHOWING");
	}
}

void GcsShowing(bool state_changed)
{
	if (state_changed)
	{
		counter_timestamp = ImGui_GetTime();
	}

	RefreshRabbitGuiAnimation();

	if (ImGui_GetTime() - counter_timestamp >= COUNTER_DURATION)
	{
		current_counter_state = GCS_SLIDING_OUT;
		Log(fatal, "GCS_SHOWING -> GCS_SLIDING_OUT");
	}
}

void GcsSlidingOut(bool state_changed)
{
	if (state_changed)
	{
		counter_slide_timestamp = ImGui_GetTime();
	}

	RefreshRabbitGuiAnimation();

	if (ImGui_GetTime() - counter_slide_timestamp <= COUNTER_SLIDE_DURATION)
	{
		float percentage = (ImGui_GetTime() - counter_slide_timestamp) / COUNTER_SLIDE_DURATION;
						
		gui.getMain().moveElement(
			counter_container.getName(),
			vec2(
				1.001f * gui.getMain().getSizeX() - (counter_container.getSizeX() - COUNTER_GUI_DISTANCE_FROM_RIGHT) * (1.0f - percentage),
				gui.getMain().getSizeY() - counter_container.getSizeY() - COUNTER_GUI_DISTANCE_FROM_BOTTOM
			)
		);
	}
	else
	{
		counter_container.setVisible(false);
		for (uint i = 0; i < counter_container.getFloatingContents().length(); i++)
			counter_container.getFloatingContents()[i].setVisible(false);

		current_counter_state = GCS_HIDDEN;
		Log(fatal, "GCS_SLIDING_OUT -> GCS_HIDDEN");
	}
}

void UpdateCounterProgressText()
{
	Log(fatal, "Updating Progress: " + level_progress);

	level_progress_text.setText(level_progress + " / " + current_level.positions.length());
	
	gui.update();
	
	float max_text_width = counter_container.getSizeX() - 3.0f * COUNTER_GUI_LEFT_RIGHT_MARGIN - rabbit_statue_image.getSizeX();
	
	counter_container.moveElement(
		level_progress_text.getName(),
		vec2(
			COUNTER_GUI_LEFT_RIGHT_MARGIN * 2.0f + rabbit_statue_image.getSizeX() + (max_text_width - level_progress_text.getSizeX()) / 2.0f,
			(counter_container.getSizeY() - level_progress_text.getSizeY()) / 2.0f
		)
	);
}

void RefreshRabbitGuiAnimation()
{
	int frame = int(floor((ImGui_GetTime() - floor(ImGui_GetTime())) * 35));

	rabbit_statue_image.setImageFile(
		"Textures/the-golden-rabbit/UI/Animations/rabbit_statue/frame_" + frame + ".png"
	);
	rabbit_statue_image.scaleToSizeY(COUNTER_GUI_RABBIT_STATUE_HEIGHT);
}

void BuildGUI()
{
	@gui = CreateIMGUI();

	gui.clear();
	gui.setup();
	
	ResizeGUIToFullscreen();
	
	// Prepare the statistics screen for a level end
	@congratulations_text = IMText("Congratulations!", FontSetup("Underdog-Regular", 128, vec4(1.0f, 0.621f, 0.0f, 1.0f), true));
	gui.getMain().addFloatingElement(congratulations_text, "congratulations_text", vec2(0.0f), 2);
	
	FontSetup statistics_font = FontSetup("Underdog-Regular", 50, vec4(1.0f, 0.781f, 0.0f, 1.0f), true);
	
	@time_taken_text = IMText("Total Time: ", statistics_font);
	gui.getMain().addFloatingElement(time_taken_text, "time_taken_text", vec2(0.0f), 2);
	
	@time_taken_text2 = IMText("", statistics_font);
	gui.getMain().addFloatingElement(time_taken_text2, "time_taken_text2", vec2(0.0f), 2);
	
	@resets_amount_text = IMText("Reset Amount: ", statistics_font);
	gui.getMain().addFloatingElement(resets_amount_text, "resets_amount_text", vec2(0.0f), 2);
	
	@resets_amount_text2 = IMText("", statistics_font);
	gui.getMain().addFloatingElement(resets_amount_text2, "resets_amount_text2", vec2(0.0f), 2);
	
	gui.update();
	
	SetStatisticsVisibility(false);
	
	// We only need to move these when the window is resized, because
	// none of the elements are placed in such a way that they would need to be resized
	// when the length of their contents change!
	gui.getMain().moveElement(congratulations_text.getName(), vec2((gui.getMain().getSizeX() - congratulations_text.getSizeX()) / 2.0f, 350.0f));
	
	gui.getMain().moveElement(time_taken_text.getName(), vec2(gui.getMain().getSizeX() / 2.0f - time_taken_text.getSizeX(), 500.0f));
	gui.getMain().moveElement(time_taken_text2.getName(), vec2(gui.getMain().getSizeX() / 2.0f, 500.0f));
	
	gui.getMain().moveElement(resets_amount_text.getName(), vec2(gui.getMain().getSizeX() / 2.0f - resets_amount_text.getSizeX(), 560.0f));
	gui.getMain().moveElement(resets_amount_text2.getName(), vec2(gui.getMain().getSizeX() / 2.0f, 560.0f));
	
	// Setup the fade image for the statue preview fullscreen fade.
	@preview_fade_image = IMImage("Textures/UI/whiteblock.tga");
	preview_fade_image.setSize(gui.getMain().getSize());
	preview_fade_image.setColor(vec4(0.0f));
	preview_fade_image.setVisible(false);
	
	gui.getMain().addFloatingElement(preview_fade_image, "preview_fade_image", vec2(0.0f), 1);

	// Setup the counter UI.
	@counter_container = IMContainer();
	gui.getMain().addFloatingElement(counter_container, "counter_container", vec2(0.0f), 2);
	
	@counter_background_image = IMImage("Textures/UI/whiteblock.tga");
	counter_background_image.setColor(vec4(vec3(0.0f), 0.4f));
	counter_container.addFloatingElement(counter_background_image, "counter_background_image", vec2(0.0f), 3);
	
	@rabbit_statue_image = IMImage("Textures/the-golden-rabbit/UI/Animations/rabbit_statue/frame_0.png");
		
	rabbit_statue_image.scaleToSizeY(COUNTER_GUI_RABBIT_STATUE_HEIGHT);
	counter_container.addFloatingElement(rabbit_statue_image, "rabbit_statue_image", vec2(0.0f), 4);
	
	// We need the widest string possible in the level, otherwise if we start with a smaller string,
	// then the text will be off-balance and we need to resize everything which might mess with our sliding in animation.
	// So we just set the max width and if we set a smaller width later, we just move it to the center.
	@level_progress_text = IMText("88 / 88", FontSetup("Underdog-Regular", int(rabbit_statue_image.getSizeY() * 0.85f), vec4(1.0f), true));
	counter_container.addFloatingElement(level_progress_text, "level_progress_text", vec2(0.0f), 4);
	
	gui.update();
	
	
	counter_container.setSize(
		vec2(
			COUNTER_GUI_LEFT_RIGHT_MARGIN * 3.0f + rabbit_statue_image.getSizeX() + level_progress_text.getSizeX(),
			COUNTER_GUI_TOP_BOTTOM_MARGIN * 3.0f + rabbit_statue_image.getSizeY()	
		)
	);
	gui.getMain().moveElement(
		counter_container.getName(),
		vec2(
			gui.getMain().getSizeX() - counter_container.getSizeX(),
			gui.getMain().getSizeY() - 400.0f
		)
	);
	
	counter_background_image.setSize(counter_container.getSize());
		
	counter_container.moveElement(
		rabbit_statue_image.getName(),
		vec2(COUNTER_GUI_LEFT_RIGHT_MARGIN, COUNTER_GUI_TOP_BOTTOM_MARGIN)
	);
	
	float max_text_width = counter_container.getSizeX() - 3.0f * COUNTER_GUI_LEFT_RIGHT_MARGIN - rabbit_statue_image.getSizeX();
	
	counter_container.moveElement(
		level_progress_text.getName(),
		vec2(
			COUNTER_GUI_LEFT_RIGHT_MARGIN * 2.0f + rabbit_statue_image.getSizeX() + (max_text_width - level_progress_text.getSizeX()) / 2.0f,
			(counter_container.getSizeY() - level_progress_text.getSizeY()) / 2.0f
		)
	);
	
	counter_container.setVisible(false);
	for (uint i = 0; i < counter_container.getFloatingContents().length(); i++)
		counter_container.getFloatingContents()[i].setVisible(false);

	gui.update();
}

// Resizes the GUI to the full game window so the GUI occupies the whole screen.
// This is a rather complicated process to calculate, and is even more confusing
// once you resize the game window since you have to do some extra work.
void ResizeGUIToFullscreen(bool bFromWindowResize = false)
{
	if (bFromWindowResize)
	{	
		// doScrenResize needed otherwise the GUI will displace wrongly
		
		// In order for our free form aspect ratioless gui to function properly
		// we need to reset the displacement and call the doScreenResize function
		// where after we will resize it with out function.
		
		// Watch out that the controls placed with addFloatElement are placed at the exact coordinats.
		// These do not scale with the GUI, so if you place something at 200.0f
		// and resize the GUI to be wider, it will stay at 200.0f, not relative to the screen.
		
		// Placing items relative to oneanother should be done with the IMContainer/IMDivider/...
		// classes. It's enough to just place the parent container relative and assign
		// all the floating elements of the container with absolute coordinates since they will
		// be relative to the parent control.

		gui.getMain().setSize(vec2(0.0f));
		gui.getMain().setDisplacement(vec2(0.0f));
		
		gui.doScreenResize();
	}

	// Secret trademarked resizing routine to size the GUI to the full window
	// rather than letting it stay on 16:9. Don't tell the devs! xD		
	
	float fDisplayRatio = 16.0f / 9.0f;
	float fXResolution, fYResolution;
	float fGUIWidth, fGUIHeight;
			
	if (screenMetrics.getScreenWidth() < screenMetrics.getScreenHeight() * fDisplayRatio)
	{
		fXResolution = screenMetrics.getScreenWidth() / screenMetrics.GUItoScreenXScale;
		fYResolution = fXResolution / fDisplayRatio;
		
		fGUIWidth = fXResolution;
		fGUIHeight = screenMetrics.getScreenHeight() / screenMetrics.GUItoScreenXScale;
		
		gui.getMain().setDisplacementY((fYResolution - fGUIHeight) / 2.0f);
		gui.getMain().setSize(vec2(fGUIWidth, fGUIHeight));
	}
	else
	{
		fYResolution = screenMetrics.getScreenHeight() / screenMetrics.GUItoScreenYScale;
		fXResolution = fYResolution * fDisplayRatio;
		
		fGUIWidth = screenMetrics.getScreenWidth() / screenMetrics.GUItoScreenYScale;
		fGUIHeight = fYResolution;
		
		gui.getMain().setDisplacementX((fXResolution - fGUIWidth) / 2.0f);
		gui.getMain().setSize(vec2(fGUIWidth, fGUIHeight));
	}
		
	gui.update();
	
	// If we don't check for this flag then the counter_container will return a null pointer,
	// since this function is also called during gui creation.
	if (bFromWindowResize)
	{
		gui.getMain().moveElement(congratulations_text.getName(), vec2((gui.getMain().getSizeX() - congratulations_text.getSizeX()) / 2.0f, 350.0f));
	
		gui.getMain().moveElement(time_taken_text.getName(), vec2(gui.getMain().getSizeX() / 2.0f - time_taken_text.getSizeX(), 500.0f));
		gui.getMain().moveElement(time_taken_text2.getName(), vec2(gui.getMain().getSizeX() / 2.0f, 500.0f));
		
		gui.getMain().moveElement(resets_amount_text.getName(), vec2(gui.getMain().getSizeX() / 2.0f - resets_amount_text.getSizeX(), 560.0f));
		gui.getMain().moveElement(resets_amount_text2.getName(), vec2(gui.getMain().getSizeX() / 2.0f, 560.0f));
	
		gui.getMain().moveElement(
			counter_container.getName(),
			vec2(
				gui.getMain().getSizeX() - counter_container.getSizeX() - COUNTER_GUI_DISTANCE_FROM_RIGHT,
				gui.getMain().getSizeY() - counter_container.getSizeY() - COUNTER_GUI_DISTANCE_FROM_BOTTOM
			)
		);
		
		preview_fade_image.setSize(gui.getMain().getSize());
	}
}