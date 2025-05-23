require 'gosu'
require 'json'

#==============================================================
#Constants Section
#==============================================================

TOP_COLOR = Gosu::Color.new(0xFF1A1A2E)    #Top Background gradient colour
BOTTOM_COLOR = Gosu::Color.new(0xFF16213E) # Bottom Background gradient colour
BUTTON_COLOR = Gosu::Color.new(0xFF0F3460) #  Button  colour
TEXT_COLOR = Gosu::Color.new(0xFFE94560)   #  Text colour
HIGHLIGHT_COLOR = Gosu::Color.new(0xDD533483)   # Highlight colour
TEXT_BG_COLOR = Gosu::Color.new(0xAAFFFFFF)    #  Text background colour
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

  end


 #===========================================================
 #Data Management Section
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
def draw_quest_list(quests, title, y_start = TOP_MARGIN + 60)
  @title_font.draw_text(title, LEFT_MARGIN, TOP_MARGIN, ZOrder::TEXT)
  
  if quests.empty?
    @font.draw_text("No quests available", LEFT_MARGIN, y_start, ZOrder::TEXT)
    return y_start + 30
  end

  y = y_start
  quest_height = 70 
  icon_size = 20
  icon_padding = 10
  
  i = 0
  while i < quests.length
    quest = quests[i]
    entry_top = y
    
    # Draw highlight if selected
    if quest == @selected_quest
      Gosu.draw_rect(LEFT_MARGIN, entry_top, 
                    width - 2 * LEFT_MARGIN, quest_height, 
                    HIGHLIGHT_COLOR, ZOrder::BUTTONS - 1)
    end
    
    
    # Draw quest text (offset to right of icon)
    text_x = LEFT_MARGIN  
    text = (i + 1).to_s + ". " + quest.name
    @font.draw_text(text, text_x, y + 10, ZOrder::TEXT)
    y += 30
    
    # Draw details with wrapping (offset same as name)
    details = "Difficulty: " + quest.difficulty.to_s + " - Reward: " + quest.reward.to_s
    y = wrap_text(details, text_x, y, width - 2 * LEFT_MARGIN )
    
    y = entry_top + quest_height
    i += 1
  end
  
  y
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

  # Draw the create quest screen (stubbed)
  # This is a placeholder for the quest creation UI 
  # and will need to be implemented with actual input handling
  # and quest creation logic. 
  def draw_create_quest
    @title_font.draw_text("Create New Quest", LEFT_MARGIN, TOP_MARGIN, ZOrder::TEXT)
    
    y = TOP_MARGIN + 60
    @font.draw_text("Name:", LEFT_MARGIN, y, ZOrder::TEXT)
    y += 30
    @font.draw_text("Description:", LEFT_MARGIN, y, ZOrder::TEXT)
    y += 30
    @font.draw_text("Difficulty (1-5):", LEFT_MARGIN, y, ZOrder::TEXT)
    y += 30
    @font.draw_text("Reward:", LEFT_MARGIN, y, ZOrder::TEXT)
  

    draw_button("Create", LEFT_MARGIN, y + 50)
    draw_button("Cancel", LEFT_MARGIN + BUTTON_WIDTH + BUTTON_MARGIN, y + 50)
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
    
    case @current_view
    when :main_menu
      draw_main_menu
    when :active_quests
      active_quests = []
      i = 0
      while i < @quests.length
        quest = @quests[i]
        if quest.status == :Active  
          active_quests << quest
        end
        i += 1
      end
      draw_quest_list(active_quests, "Active Quests")
    when :completed_quests
      completed_quests = []
      i = 0
      while i < @quests.length
        quest = @quests[i]
        if quest.status == :Completed
          completed_quests << quest
        end
        i += 1
      end
      draw_quest_list(completed_quests, "Completed Quests")
    when :accept_quest
      available_quests = []
      i = 0
      while i < @quests.length
        quest = @quests[i]
        if quest.status == :NotStarted
          available_quests << quest
        end
        i += 1
      end
      draw_quest_list(available_quests, "Available Quests")
    when :complete_quest
      active_quests = []
      i = 0
      while i < @quests.length
        quest = @quests[i]
        if quest.status == :Active
          active_quests << quest
        end
        i += 1
      end
      draw_quest_list(active_quests, "Quests to Complete")
    when :create_quest
      draw_create_quest
    end
    
    draw_message
    
    # Draw back button if not on main menu
    unless @current_view == :main_menu
      draw_button("Back", width - BUTTON_WIDTH - LEFT_MARGIN, height - BUTTON_HEIGHT - 20)
    end
  end

  #============================================================
  # Input Handling Section
  #============================================================

  # Handle mouse button down events
  def button_down(id)
    case id
    when Gosu::MsLeft
      handle_mouse_click
    end
  end

  # Main mouse click handler
  def handle_mouse_click
    case @current_view
    when :main_menu
      handle_main_menu_click
    when :active_quests, :completed_quests, :accept_quest, :complete_quest
      handle_quest_list_click
    when :create_quest
      handle_create_quest_click
    end
    
    # Handle back button
    unless @current_view == :main_menu
      if area_clicked(width - BUTTON_WIDTH - LEFT_MARGIN, height - BUTTON_HEIGHT - 20, 
                      width - LEFT_MARGIN, height - 20)
        @select_sound.play(0.6)
        @current_view = :main_menu
        @selected_quest = nil
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
      if option == :exit
        close
      elsif option == :save_progress
        save_progress_to_file('quests.json')
        @save_file_sound.play(0.6)
      else
        @current_view = option
      end
      break
    end
    button_y += BUTTON_HEIGHT + BUTTON_MARGIN
    i += 1
  end
end

  # Handle clicks on quest lists
  def handle_quest_list_click
  quests = case @current_view
    when :active_quests then @quests.select { |quest| quest.status == :Active }
    when :completed_quests then @quests.select { |quest| quest.status == :Completed }
    when :accept_quest then @quests.select { |quest| quest.status == :NotStarted }
    when :complete_quest then @quests.select { |quest| quest.status == :Active }
    else []
  end
  
  return if quests.empty?
  
  y_start = TOP_MARGIN + 60
  quest_height = 70 
  i = 0
  while i < quests.length
    top = y_start + (quest_height * i)
    bottom = top + quest_height
    
    if area_clicked(LEFT_MARGIN, top, width - LEFT_MARGIN, bottom)
      @selected_quest = quests[i]
      @select_sound.play(0.6)
      
      case @current_view
      when :accept_quest
        @accept_quest_sound.play(0.6) 
        quests[i].status = :Active
        show_message(quests[i].name + " accepted!")
        @current_view = :main_menu
      when :complete_quest
        quests[i].status = :Completed
        @complete_quest_sound.play(0.6)
        show_message(quests[i].name + " completed!")
        @current_view = :main_menu
      end
      break
    end
    i += 1
  end
end

  # Handle clicks on the create quest screen (stubbed)
  def handle_create_quest_click
    # Check if Create button clicked
    if area_clicked(LEFT_MARGIN, TOP_MARGIN + 60 + 50 + 50, 
                    LEFT_MARGIN + BUTTON_WIDTH, TOP_MARGIN + 60 + 50 + 50 + BUTTON_HEIGHT)
      show_message("Create quest functionality not implemented yet")
      @current_view = :main_menu
    # Check if Cancel button clicked
    elsif area_clicked(LEFT_MARGIN + BUTTON_WIDTH + BUTTON_MARGIN, TOP_MARGIN + 60 + 50 + 50, 
                       LEFT_MARGIN + 2 * BUTTON_WIDTH + BUTTON_MARGIN, TOP_MARGIN + 60 + 50 + 50 + BUTTON_HEIGHT)
      @current_view = :main_menu
    end
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


# TODO:
# - Implement quest creation functionality 
# - Add quest pages to handle large number of quests

#Stretch goals:
# - Add a search bar for quests
# - Implement quest filtering and sorting 