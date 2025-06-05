require 'gosu'
require 'json'

#==============================================================
# Constants Section
#==============================================================

TOP_COLOR = Gosu::Color.new(0xFF1A1A2E)    # Top Background gradient colour
BOTTOM_COLOR = Gosu::Color.new(0xFF16213E) # Bottom Background gradient colour
BUTTON_COLOR = Gosu::Color.new(0xFF0F3460) # Button colour
TEXT_COLOR = Gosu::Color.new(0xFFE94560)   # Text colour
HIGHLIGHT_COLOR = Gosu::Color.new(0xDD533483) # Highlight colour
TEXT_BG_COLOR = Gosu::Color.new(0xAAFFFFFF)   # Text background colour
TEXT_FIELD_COLOR = Gosu::Color.new(0x880F3460) # text fields colour

# Z-order constants for drawing layers
module ZOrder
  BACKGROUND, TEXT, BUTTONS = *0..2
end

#==============================================================
# Data Section
#==============================================================

# Quest class representing a single quest with its attributes
class Quest
  attr_accessor :name, :description, :difficulty, :reward, :status

  def initialize(name, description, difficulty, reward, status = :NotStarted)
    @name = name
    @description = description
    @difficulty = difficulty
    @reward = reward
    @status = status
  end

  # Convert quest to a hash for JSON serialization
  def to_hash
    {
      name: name,
      description: description,
      difficulty: difficulty,
      reward: reward,
      status: status
    }
  end
end

#==============================================================
# Main Application Section
#==============================================================

# Main application window class
class QuestTracker < Gosu::Window
  # UI constants
  BUTTON_WIDTH = 200
  BUTTON_HEIGHT = 40
  BUTTON_MARGIN = 20
  LEFT_MARGIN = 50
  TOP_MARGIN = 50
  TEXT_OFFSET = 10
  FILTER_CONTROLS_HEIGHT = 120  # Added constant for filter controls area height

  #==========================================================
  # Initialization and main methods
  #==========================================================

  # Initialize the window and load resources
  def initialize
    super 1024, 768
    self.caption = "Quest Tracking System"
    @font = Gosu::Font.new(20, name: "PressStart2P-Regular.ttf")          
    @title_font = Gosu::Font.new(30, name: "PressStart2P-Regular.ttf")    
    @text = Gosu::TextInput.new
    @quests = []                       
    @current_view = :main_menu          
    @selected_quest = nil               
    @message = ""                       
    @message_time = 0                   
    load_quests_from_file('quests.json') 
    @bgm = Gosu::Song.new("Sounds/BackgroundMusic.mp3")
    @bgm.volume = 0.2  
    @bgm.play(true)  

    # Load sound effects
    @select_sound = Gosu::Sample.new("Sounds/Select.wav")
    @accept_quest_sound = Gosu::Sample.new("Sounds/AcceptQuest.wav")
    @complete_quest_sound = Gosu::Sample.new("Sounds/CompleteQuest.wav")
    @save_file_sound = Gosu::Sample.new("Sounds/SaveFile.wav")

    # Load menu icons
    @menu_icons = {
      active: Gosu::Image.new("Images/active_quests.png"),
      completed: Gosu::Image.new("Images/completed_quests.png"),
      accept: Gosu::Image.new("Images/accept_quest.png"),
      complete: Gosu::Image.new("Images/complete_quest.png"),
      create: Gosu::Image.new("Images/new_quest.png"),
      save: Gosu::Image.new("Images/save.png"),
      exit: Gosu::Image.new("Images/exit.png")
    }
    @current_page = 0
    @quests_per_page = 5

    @name_input = Gosu::TextInput.new
    @desc_input = Gosu::TextInput.new
    @diff_input = Gosu::TextInput.new
    @reward_input = Gosu::TextInput.new
    @active_input = nil
    @search_input = Gosu::TextInput.new
    @search_active = false

    @input_fields = {
      name: { x: LEFT_MARGIN + 350, y: TOP_MARGIN + 60, width: 300, height: 30 },
      desc: { x: LEFT_MARGIN + 350, y: TOP_MARGIN + 90, width: 300, height: 30 },
      diff: { x: LEFT_MARGIN + 350, y: TOP_MARGIN + 120, width: 300, height: 30 },
      reward: { x: LEFT_MARGIN + 350, y: TOP_MARGIN + 150, width: 300, height: 30 }
    }
    
    # Filter and sort variables
    @filter_difficulty = nil
    @sort_by = :name
    @sort_order = :asc
  end

  #===========================================================
  # Data Management Section
  #===========================================================

  # Load quests from a JSON file
  def load_quests_from_file(file_name)
    if File.exist?(file_name)
      data = JSON.parse(File.read(file_name), symbolize_names: true)
      @quests = []
      i = 0
      while i < data.length
        quest_data = data[i]
        @quests << Quest.new(
          quest_data[:name],
          quest_data[:description],
          quest_data[:difficulty],
          quest_data[:reward],
          quest_data[:status].to_sym
        )
        i += 1
      end
    else
      @quests = []
    end
  end

  # Save quests to a JSON file
  def save_progress_to_file(file_name)
    quest_data = []
    i = 0
    while i < @quests.length
      quest_data << @quests[i].to_hash
      i += 1
    end
    File.write(file_name, JSON.pretty_generate(quest_data))
    show_message("Progress saved!")
  end

  #===========================================================
  # Filtering and Sorting Methods
  #===========================================================
  
  def filter_quests(quests)
    filtered = []
    i = 0
    while i < quests.length
      quest = quests[i]
      
      # Apply status filter based on current view
      status_match = case @current_view
                    when :active_quests 
                      then quest.status == :Active
                    when :completed_quests 
                      then quest.status == :Completed
                    when :accept_quest 
                      then quest.status == :NotStarted
                    when :complete_quest 
                      then quest.status == :Active
                    else true
                    end
      
      # Apply difficulty filter if set
      difficulty_match = @filter_difficulty.nil? || quest.difficulty == @filter_difficulty
      
      # Apply search filter if search term exists
      search_match = true
      if !@search_input.text.empty?
        search_term = @search_input.text.downcase
        search_match = quest.name.downcase.include?(search_term) ||
                       quest.description.downcase.include?(search_term) ||
                       quest.reward.downcase.include?(search_term) ||
                       quest.difficulty.to_s.downcase.include?(search_term)
      end
      
      if status_match && difficulty_match && search_match
        filtered << quest
      end
      i += 1
    end
    filtered
  end
  
  def sort_quests(quests)
    return quests if quests.empty?
    
    sorted = quests.dup
    
    # Bubble sort implementation with while loops
    i = 0
    while i < sorted.length - 1
      j = 0
      while j < sorted.length - i - 1
        a = sorted[j]
        b = sorted[j + 1]
        swap = false
        
        case @sort_by
        when :name
          comparison = a.name.downcase <=> b.name.downcase
        when :difficulty
          comparison = a.difficulty <=> b.difficulty
        when :reward
          comparison = a.reward.downcase <=> b.reward.downcase
        else
          comparison = 0
        end
        
        if @sort_order == :asc
          swap = comparison > 0
        else
          swap = comparison < 0
        end
        
        if swap
          sorted[j], sorted[j + 1] = sorted[j + 1], sorted[j]
        end
        
        j += 1
      end
      i += 1
    end
    
    sorted
  end
  
  def get_visible_quests
    # First filter by status (based on current view)
    filtered = filter_quests(@quests)
    
    # Then sort
    sorted = sort_quests(filtered)
    
    sorted
  end

  #===========================================================
  # UI and Drawing Section
  #===========================================================

  # Display a temporary message
  def show_message(text)
    @message = text
    @message_time = Gosu.milliseconds + 3000 # Show for 3 seconds
  end

  # Draw a button with text
  def draw_button(text, x, y, width = nil, height = BUTTON_HEIGHT)
    text_width = @font.text_width(text)
    button_width = width || text_width + 40  
    
    # Draw button background (behind text)
    Gosu.draw_rect(x, y, button_width, height, BUTTON_COLOR, ZOrder::BUTTONS - 1)
    
    # Draw button text (on top of background)
    text_x = x + (button_width - text_width) / 2
    text_y = y + (height - @font.height) / 2
    @font.draw_text(text, text_x, text_y, ZOrder::BUTTONS, 1.0, 1.0, TEXT_COLOR)
    
    button_width
  end

  # Draw the main menu screen
  def draw_main_menu
    title_width = @title_font.text_width("Quest Tracking System")
    @title_font.draw_text("Quest Tracking System", (width - title_width) / 2, TOP_MARGIN, ZOrder::TEXT)
    
    button_y = TOP_MARGIN + 80
    button_x = (width - BUTTON_WIDTH) / 2
    
    options = [
      { text: "View Active Quests", icon: :active },
      { text: "View Completed Quests", icon: :completed },
      { text: "Accept a New Quest", icon: :accept },
      { text: "Complete a Quest", icon: :complete },
      { text: "Create a New Quest", icon: :create },
      { text: "Save Progress", icon: :save },
      { text: "Exit", icon: :exit }
    ]
    
    i = 0
    while i < options.length
      icon = @menu_icons[options[i][:icon]]
      icon.draw(
        button_x - 60,                     
        button_y + (BUTTON_HEIGHT - icon.height * 0.1) / 2,  
        ZOrder::BUTTONS,                    
        0.1, 0.1                           
      )
      
      # Draw button text
      draw_button(options[i][:text], button_x, button_y)
      
      button_y += BUTTON_HEIGHT + BUTTON_MARGIN
      i += 1
    end
  end

  # Draw a list of quests with a title
  def draw_quest_list(quests, title, y_start = TOP_MARGIN + 180)  # Increased starting y position to account for filter controls
    # Draw title
    @title_font.draw_text(title, LEFT_MARGIN, TOP_MARGIN, ZOrder::TEXT)
    
    # Draw search and filter controls
    draw_search_and_filter_controls(TOP_MARGIN + 40)
    
    visible_quests = get_visible_quests
    
    if visible_quests.empty?
      @font.draw_text("No quests found matching criteria", LEFT_MARGIN, y_start, ZOrder::TEXT)
      return y_start + 30
    end

    # Calculate pagination
    total_pages = (visible_quests.length.to_f / @quests_per_page).ceil
    start_index = @current_page * @quests_per_page
    end_index = [start_index + @quests_per_page, visible_quests.length].min - 1

    y = y_start
    quest_height = 90  # Increased quest height for better spacing
    
    # Draw quests for current page
    i = start_index
    while i <= end_index
      quest = visible_quests[i]
      entry_top = y
      
      # Draw highlight if selected
      if quest == @selected_quest
        Gosu.draw_rect(LEFT_MARGIN, entry_top, 
                      width - 2 * LEFT_MARGIN, quest_height, 
                      HIGHLIGHT_COLOR, ZOrder::BUTTONS - 1)
      end
      
      # Draw quest text
      text_x = LEFT_MARGIN  
      text = (i + 1).to_s + ". " + quest.name
      @font.draw_text(text, text_x, y + 10, ZOrder::TEXT)
      y += 30
      
      # Draw details with wrapping
      details = "Difficulty: " + quest.difficulty.to_s + " - Reward: " + quest.reward.to_s
      y = wrap_text(details, text_x, y, width - 2 * LEFT_MARGIN)
      
      y = entry_top + quest_height
      i += 1
    end
    
    # Draw pagination controls
    draw_pagination_controls(y + 20, total_pages)
    
    y
end

  def draw_search_and_filter_controls(y)
  # Draw sort controls first (at the top)
  sort_label_width = @font.text_width("Sort:") + 10
  draw_button("Sort:", LEFT_MARGIN, y, sort_label_width, 30)
  
  # Sort options - calculate widths based on text
  sort_options = [
    { text: "Name", value: :name },
    { text: "Difficulty", value: :difficulty },
    { text: "Reward", value: :reward }
  ]
  
  # Calculate button widths including arrow space
  button_widths = sort_options.map do |option|
    base_width = @font.text_width(option[:text])
    if @sort_by == option[:value]
      base_width + @font.text_width(" ↑") # Account for sort arrow
    else
      base_width
    end + 20 # Padding
  end
  
  # Position buttons with spacing
  x_pos = LEFT_MARGIN + sort_label_width + 20
  sort_options.each_with_index do |option, i|
    width = button_widths[i]
    
    color = @sort_by == option[:value] ? HIGHLIGHT_COLOR : BUTTON_COLOR
    Gosu.draw_rect(x_pos, y, width, 30, color, ZOrder::BUTTONS - 1)
    
    # Add arrow indicator for sort order
    text = option[:text]
    if @sort_by == option[:value]
      text += @sort_order == :asc ? " ↑" : " ↓"
    end
    
    text_x = x_pos + (width - @font.text_width(text)) / 2
    @font.draw_text(text, text_x, y + 5, ZOrder::BUTTONS)
    
    x_pos += width + 20 # Space between buttons
  end
  
  # Draw search bar below sort controls with more spacing
  search_y = y + 50 # Increased spacing
  search_width = 300
  Gosu.draw_rect(LEFT_MARGIN, search_y, search_width, 30, TEXT_FIELD_COLOR, ZOrder::BUTTONS - 1)
  
  # Draw search text or placeholder
  text = @search_input.text.empty? ? "Search..." : @search_input.text
  text_color = @search_input.text.empty? ? Gosu::Color::GRAY : TEXT_COLOR
  @font.draw_text(text, LEFT_MARGIN + 5, search_y + 5, ZOrder::TEXT, 1.0, 1.0, text_color)
  
  # Draw cursor if active
  if @search_active && (Gosu.milliseconds / 500) % 2 == 0
    cursor_x = LEFT_MARGIN + 5 + @font.text_width(@search_input.text[0...@search_input.caret_pos])
    Gosu.draw_rect(cursor_x, search_y + 5, 2, @font.height - 10, TEXT_COLOR, ZOrder::TEXT)
  end
  
  # Draw filter controls below search with more spacing
  filter_y = search_y + 50 # Increased spacing
  filter_label_width = @font.text_width("Filter:") + 10
  draw_button("Filter:", LEFT_MARGIN, filter_y, filter_label_width, 30)
  
  # Difficulty filter buttons - calculate widths based on text
  diff_options = ["All", "1", "2", "3", "4", "5"]
  diff_widths = diff_options.map { |text| @font.text_width(text) + 20 } # Add padding
  
  # Position buttons with spacing
  diff_x = LEFT_MARGIN + filter_label_width + 20
  diff_options.each_with_index do |text, i|
    difficulty = i == 0 ? nil : i
    width = diff_widths[i]
    
    color = @filter_difficulty == difficulty ? HIGHLIGHT_COLOR : BUTTON_COLOR
    Gosu.draw_rect(diff_x, filter_y, width, 30, color, ZOrder::BUTTONS - 1)
    
    text_x = diff_x + (width - @font.text_width(text)) / 2
    @font.draw_text(text, text_x, filter_y + 5, ZOrder::BUTTONS)
    
    diff_x += width + 15 # Space between buttons
  end
end

  def draw_pagination_controls(y, total_pages)
    # Only draw controls if there are multiple pages
    return if total_pages <= 1

    # Draw page info
    page_text = "Page #{@current_page + 1} of #{total_pages}"
    text_width = @font.text_width(page_text)
    @font.draw_text(page_text, (width - text_width) / 2, y, ZOrder::TEXT)

    # Draw previous button (with increased spacing)
    if @current_page > 0
      draw_button("< Previous", width / 2 - 250, y + 40)  # Moved further left
    end

    # Draw next button (with increased spacing)
    if @current_page < total_pages - 1
      draw_button("Next >", width / 2 + 150, y + 40)  # Moved further right
    end
  end

  def wrap_text(text, x, y, max_width)
    words = text.split(' ')
    current_line = ''
    i = 0
    while i < words.length
      word = words[i]
      test_line = current_line.empty? ? word : current_line + " " + word
      if @font.text_width(test_line) <= max_width
        current_line = test_line
      else
        # Draw the current line
        @font.draw_text(current_line, x, y, ZOrder::TEXT)
        y += @font.height
        current_line = word
      end
      i += 1
    end
    
    # Draw the last line
    unless current_line.empty?
      @font.draw_text(current_line, x, y, ZOrder::TEXT)
      y += @font.height
    end
    
    y
  end

  # Draw the create quest screen
  def draw_create_quest
    @title_font.draw_text("Create New Quest", LEFT_MARGIN, TOP_MARGIN, ZOrder::TEXT)
    
    # Draw labels
    @font.draw_text("Name:", LEFT_MARGIN, TOP_MARGIN + 60, ZOrder::TEXT)
    @font.draw_text("Description:", LEFT_MARGIN, TOP_MARGIN + 90, ZOrder::TEXT)
    @font.draw_text("Difficulty (1-5):", LEFT_MARGIN, TOP_MARGIN + 120, ZOrder::TEXT)
    @font.draw_text("Reward:", LEFT_MARGIN, TOP_MARGIN + 150, ZOrder::TEXT)
    
    # Draw input fields
    draw_input_field(@name_input, :name, "Enter quest name")
    draw_input_field(@desc_input, :desc, "Enter description")
    draw_input_field(@diff_input, :diff, "1-5")
    draw_input_field(@reward_input, :reward, "Gold, items, etc.")
    
    # Draw buttons
    draw_button("Create", LEFT_MARGIN, TOP_MARGIN + 200)
    draw_button("Cancel", LEFT_MARGIN + BUTTON_WIDTH + BUTTON_MARGIN, TOP_MARGIN + 200)
  end

  def draw_input_field(text_input, field_key, placeholder)
    field = @input_fields[field_key]
    is_active = @active_input == field_key
    
    # Draw background
    color = is_active ? TEXT_FIELD_COLOR : TEXT_FIELD_COLOR
    Gosu.draw_rect(field[:x], field[:y], field[:width], field[:height], color, ZOrder::BUTTONS - 1)
    
    # Draw text or placeholder
    text = text_input.text.empty? ? placeholder : text_input.text
    text_color = text_input.text.empty? ? Gosu::Color::GRAY : TEXT_COLOR
    
    # Clip text if too long
    text_width = @font.text_width(text)
    if text_width > field[:width] - 10
      visible_text = ""
      i = text.length - 1
      while i >= 0
        test_text = "..." + text[i..-1]
        if @font.text_width(test_text) <= field[:width] - 10
          visible_text = test_text
          break
        end
        i += 1
      end
      text = visible_text
    end
    
    @font.draw_text(text, field[:x] + 5, field[:y] + 5, ZOrder::TEXT, 1.0, 1.0, text_color)
    
    # Draw cursor if active
    if is_active && (Gosu.milliseconds / 500) % 2 == 0
      cursor_x = field[:x] + 5 + @font.text_width(text_input.text[0...text_input.caret_pos])
      Gosu.draw_rect(cursor_x, field[:y] + 5, 2, @font.height - 10, TEXT_COLOR, ZOrder::TEXT)
    end
  end

  # Draw the gradient background
  def draw_background
    draw_quad(0, 0, TOP_COLOR, width, 0, TOP_COLOR, 0, height, BOTTOM_COLOR, width, height, BOTTOM_COLOR, ZOrder::BACKGROUND)
  end

  # Draw the temporary message if active
  def draw_message
    if Gosu.milliseconds < @message_time
      text_width = @font.text_width(@message)
      x = (width - text_width) / 2
      @font.draw_text(@message, x, height - 50, ZOrder::TEXT, 1.0, 1.0, Gosu::Color::YELLOW)
    end
  end
  
  #============================================================
  # Drawing Methods
  #============================================================

  # Main draw method
  def draw
    draw_background
    
    # Replace case statement with if-elsif chain
    if @current_view == :main_menu
      draw_main_menu
    elsif @current_view == :active_quests
      draw_quest_list(@quests, "Active Quests")
    elsif @current_view == :completed_quests
      draw_quest_list(@quests, "Completed Quests")
    elsif @current_view == :accept_quest
      draw_quest_list(@quests, "Available Quests")
    elsif @current_view == :complete_quest
      draw_quest_list(@quests, "Quests to Complete")
    elsif @current_view == :create_quest
      draw_create_quest
    end
    
    draw_message
    
    # Draw back button if not on main menu
    if @current_view != :main_menu
      draw_button("Back", width - BUTTON_WIDTH - LEFT_MARGIN, height - BUTTON_HEIGHT - 20)
    end
  end

  #============================================================
  # Input Handling Section
  #============================================================

  # Handle mouse button down events
  def button_down(id)
    if id == Gosu::MsLeft
      handle_mouse_click
    elsif id == Gosu::KbEscape
      if @search_active
        @search_active = false
        self.text_input = nil
      elsif @current_view == :create_quest && @active_input
        @active_input = nil
        self.text_input = nil
      end
    elsif id == Gosu::KbTab && @current_view == :create_quest && @active_input
      cycle_input_fields
    end
  end

  def cycle_input_fields
    fields = [:name, :desc, :diff, :reward]
    current_index = -1

    i = 0
    while i < fields.size
      if fields[i] == @active_input
        current_index = i
        break
      end
      i += 1
    end

    next_index = (current_index + 1) % fields.size
    @active_input = fields[next_index]

    if @active_input == :name 
      self.text_input = @name_input
    elsif @active_input == :desc 
      self.text_input = @desc_input
    elsif @active_input == :diff 
      self.text_input = @diff_input
    elsif @active_input == :reward 
      self.text_input = @reward_input
    end
  end

  # Main mouse click handler
def handle_mouse_click
  mouse_x = self.mouse_x
  mouse_y = self.mouse_y

  # Handle search input first
  search_y = TOP_MARGIN + 90 # Adjusted to match the actual drawn position
  search_width = 300
  if area_clicked(LEFT_MARGIN, search_y, LEFT_MARGIN + search_width, search_y + 30)
    @search_active = true
    self.text_input = @search_input
    return
  else
    @search_active = false
    self.text_input = nil if self.text_input == @search_input
  end

  # Handle sort clicks (top row)
  if @current_view != :main_menu && @current_view != :create_quest
    sort_y = TOP_MARGIN + 40 # Adjusted to match the draw position
    sort_label_width = @font.text_width("Sort:") + 10
    sort_x = LEFT_MARGIN + sort_label_width + 20
    
    sort_options = [
      { text: "Name", value: :name },
      { text: "Difficulty", value: :difficulty },
      { text: "Reward", value: :reward }
    ]
    
    # Calculate button positions based on actual drawing
    current_x = sort_x
    i = 0
    while i < sort_options.length
      option = sort_options[i]
      text = option[:text]
      text += @sort_by == option[:value] ? (@sort_order == :asc ? " ↑" : " ↓") : ""
      button_width = @font.text_width(text) + 20
      
      if area_clicked(current_x, sort_y, current_x + button_width, sort_y + 30)
        if @sort_by == option[:value]
          @sort_order = @sort_order == :asc ? :desc : :asc
        else
          @sort_by = option[:value]
          @sort_order = :asc
        end
        @current_page = 0 # Reset to first page when changing sort
        @select_sound.play(0.6)
        return
      end
      
      current_x += button_width + 20
      i += 1
    end
    
    # Handle difficulty filter clicks - CORRECTED POSITIONING
    filter_y = TOP_MARGIN + 140 # This matches the actual drawn position (search_y + 50)
    filter_label_width = @font.text_width("Filter:") + 10
    diff_x = LEFT_MARGIN + filter_label_width + 20
    
    diff_options = ["All", "1", "2", "3", "4", "5"]
    
    i = 0
    while i < diff_options.length
      text = diff_options[i]
      button_width = @font.text_width(text) + 20
      if area_clicked(diff_x, filter_y, diff_x + button_width, filter_y + 30)
        @filter_difficulty = i == 0 ? nil : i
        @current_page = 0 # Reset to first page when changing filter
        @select_sound.play(0.6)
        return
      end
      diff_x += button_width + 15
      i += 1
    end
  end

  # Handle main menu clicks
  if @current_view == :main_menu
    handle_main_menu_click
  elsif @current_view == :active_quests || @current_view == :completed_quests || 
        @current_view == :accept_quest || @current_view == :complete_quest
    handle_quest_list_click
  elsif @current_view == :create_quest
    handle_create_quest_click
  end
  
  # Back button
  if @current_view != :main_menu
    if area_clicked(width - BUTTON_WIDTH - LEFT_MARGIN, height - BUTTON_HEIGHT - 20, 
                   width - LEFT_MARGIN, height - 20)
      @select_sound.play(0.6)
      @current_view = :main_menu
      @selected_quest = nil
      @filter_difficulty = nil
      @search_input.text = ""
      @search_active = false
      self.text_input = nil
    end
  end
end
  # Handle clicks on the main menu
  def handle_main_menu_click
    button_y = TOP_MARGIN + 80
    button_x = (width - BUTTON_WIDTH) / 2

    options = [
      :active_quests, :completed_quests, :accept_quest, :complete_quest, 
      :create_quest, :save_progress, :exit
    ]

    i = 0
    while i < options.length
      if area_clicked(button_x, button_y, button_x + BUTTON_WIDTH, button_y + BUTTON_HEIGHT)
        @select_sound.play(0.6)
        option = options[i]
        @search_input.text = ""
        @search_active = false
        self.text_input = nil
        if option == :exit
          close
        elsif option == :save_progress
          save_progress_to_file('quests.json')
          @save_file_sound.play(0.6)
        else
          @current_view = option
          @current_page = 0  # Reset to first page when changing views
          @filter_difficulty = nil # Reset filter when changing views
        end
        break
      end
      button_y += BUTTON_HEIGHT + BUTTON_MARGIN
      i += 1
    end
  end

  # Handle clicks on quest lists
  def handle_quest_list_click
  visible_quests = get_visible_quests
  
  # Calculate pagination bounds
  total_pages = (visible_quests.length.to_f / @quests_per_page).ceil
  start_index = @current_page * @quests_per_page
  end_index = [start_index + @quests_per_page, visible_quests.length].min - 1

  # Check clicks on quest items (only for current page)
  y = TOP_MARGIN + 180  # This must match the y_start in draw_quest_list
  i = start_index
  while i <= end_index
    quest_height = 90  # This must match quest_height in draw_quest_list
    if area_clicked(LEFT_MARGIN, y, width - LEFT_MARGIN, y + quest_height)
      @selected_quest = visible_quests[i]
      @select_sound.play(0.6)

      # Handle quest actions
      if @current_view == :accept_quest
        @selected_quest.status = :Active
        @accept_quest_sound.play(0.6)
        show_message("Quest accepted: #{@selected_quest.name}")
      elsif @current_view == :complete_quest
        @selected_quest.status = :Completed
        @complete_quest_sound.play(0.6)
        show_message("Quest completed: #{@selected_quest.name}")
      end
      break
    end
    y += quest_height
    i += 1
  end

  # Handle pagination controls
  pagination_y = y + 20

  # Previous page button
  if @current_page > 0 && area_clicked(width / 2 - 250, pagination_y + 40, width / 2 - 150, pagination_y + 40 + BUTTON_HEIGHT)
    @current_page -= 1
    @select_sound.play(0.6)
    return
  end

  # Next page button
  if @current_page < total_pages - 1 && area_clicked(width / 2 + 150, pagination_y + 40, width / 2 + 250, pagination_y + 40 + BUTTON_HEIGHT)
    @current_page += 1
    @select_sound.play(0.6)
    return
  end
end

  def handle_create_quest_click
    # Check input fields using while loop
    fields = @input_fields.keys
    i = 0
    while i < fields.size
      field = @input_fields[fields[i]]
      if area_clicked(field[:x], field[:y], field[:x] + field[:width], field[:y] + field[:height])
        @active_input = fields[i]
        if fields[i] == :name
          self.text_input = @name_input
        elsif fields[i] == :desc
          self.text_input = @desc_input
        elsif fields[i] == :diff
          self.text_input = @diff_input
        elsif fields[i] == :reward
          self.text_input = @reward_input
        end
        return
      end
      i += 1
    end

    # Check buttons
    if area_clicked(LEFT_MARGIN, TOP_MARGIN + 200, 
                   LEFT_MARGIN + BUTTON_WIDTH, TOP_MARGIN + 200 + BUTTON_HEIGHT)
      create_new_quest
    elsif area_clicked(LEFT_MARGIN + BUTTON_WIDTH + BUTTON_MARGIN, TOP_MARGIN + 200, 
                      LEFT_MARGIN + 2 * BUTTON_WIDTH + BUTTON_MARGIN, TOP_MARGIN + 200 + BUTTON_HEIGHT)
      reset_creation_form
      @current_view = :main_menu
    else
      @active_input = nil
      self.text_input = nil
    end
  end
  
  def create_new_quest
    # Validate inputs
    if @name_input.text.empty?
      show_message("Quest name cannot be empty!")
      return
    end
    
    difficulty = @diff_input.text.to_i
    if difficulty < 1 || difficulty > 5
      show_message("Difficulty must be between 1-5")
      return
    end
    
    if @reward_input.text.empty?
      show_message("Reward cannot be empty!")
      return
    end
    
    # Create new quest
    new_quest = Quest.new(
      @name_input.text,
      @desc_input.text,
      difficulty,
      @reward_input.text,
      :NotStarted
    )
    
    @quests << new_quest
    show_message("Quest '#{new_quest.name}' created!")
    reset_creation_form
    @current_view = :main_menu
  end

  def reset_creation_form
    @name_input.text = ""
    @desc_input.text = ""
    @diff_input.text = ""
    @reward_input.text = ""
    @active_input = nil
    self.text_input = nil
  end

  # Check if a rectangular area was clicked
  def area_clicked(leftX, topY, rightX, bottomY)
    mouse_x >= leftX && mouse_x <= rightX && mouse_y >= topY && mouse_y <= bottomY
  end

  # Show the mouse cursor
  def needs_cursor?
    true
  end
end

QuestTracker.new.show

#I acknowledge the use of Vs code extensions that provide help using intellisense such as " Ruby Solargraph" with assistance with the code thrugh inline documentation and the comments.