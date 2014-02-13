require 'rubygame'

ZOOM = 7

module Chip8

  FONTSET = [
    0xF0, 0x90, 0x90, 0x90, 0xF0, # 0
    0x20, 0x60, 0x20, 0x20, 0x70, # 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, # 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, # 3
    0x90, 0x90, 0xF0, 0x10, 0x10, # 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, # 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, # 6
    0xF0, 0x10, 0x20, 0x40, 0x40, # 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, # 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, # 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, # A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, # B
    0xF0, 0x80, 0x80, 0x80, 0xF0, # C
    0xE0, 0x90, 0x90, 0x90, 0xE0, # D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, # E
    0xF0, 0x80, 0xF0, 0x80, 0x80  # F
  ]

  OPCODES = []

  class CPU

    attr_accessor :pc, :draw_flag, :key_press

    def initialize(memory, gpu, keys)
      @memory = memory
      @gpu = gpu
      @keys = keys
      @key_press = false
      @pc = 0x200
      @draw_flag = false
      @opcode = 0
      @i = 0
      @sp = 0

      @v = [0] * 16
      @stack = [0] * 16

      @delay_timer = 0
      @sound_timer = 0
    end

    def execute(op)
      x = (op & 0x0F00) >> 8
      y = (op & 0x00F0) >> 4
      @pc += 2
      case op & 0xF000
        when 0x0000
        case op & 0x000F
          when 0x0000 then @gpu.gfx = [0] * 2048; @draw_flag = true
          when 0x000E then @sp -= 1; @pc = @stack[@sp] + 2; @stack[@sp] = 0
          else raise Exception.new "Unknown opcode; 0x#{op.to_s(16)}"
        end
        when 0x1000 then @pc = (op & 0x0FFF)
        when 0x2000 then @stack[@sp] = @pc - 2; @sp += 1; @pc = op & 0x0FFF
        when 0x3000 then @pc += 2 if @v[x] == op & 0x00FF
        when 0x4000 then @pc += 2 if @v[x] != op & 0x00FF
        when 0x5000 then @pc += 2 if @v[x] == @v[y]
        when 0x6000 then @v[x] = op & 0x00FF
        when 0x7000 then @v[x] += op & 0x00FF; @v[x] %= 256
        when 0x8000 then
        case op & 0x000F
          when 0x0000 then @v[x] = @v[y]
          when 0x0001 then @v[x] = @v[x] | @v[y]
          when 0x0002 then @v[x] = @v[x] & @v[y]
          when 0x0003 then @v[x] = @v[x] ^ @v[y]
          when 0x0004 then
            @v[0xF] = 0
            if (@v[x] += @v[y]) > 255
              @v[0xF] = 1
              @v[x] %= 256
            end
          when 0x0005 then
            @v[0xF] = 0
            if (@v[x] -= @v[y]) < 0
              @v[0xF] = 1
              @v[x] %= 256
            end
          when 0x0006 then @v[0xF] = @v[x] & 0x1; @v[x] >>= 1
          when 0x000E then @v[0xF] = @v[x] >> 7; @v[x] <<= 1
          else raise Exception.new "Unknown opcode; 0x#{op.to_s(16)}"
        end
        when 0x9000 then @pc += 2 if @v[x] != @v[y]
        when 0xA000 then @i = op & 0x0FFF
        when 0xB000 then @pc = (op & 0x0FFF) + @v[0]
        when 0xC000 then @v[x] = (op & 0x00FF) & rand(0xFF)
        when 0xD000 then do_draw_stuff(op)
        when 0xE000 then
        case op & 0x00FF
          when 0x009E then @pc += 2 if @keys[@v[x]] == 1
          when 0x00A1 then @pc += 2 if @keys[@v[x]] == 0
          else raise Exception.new "Unknown opcode; 0x#{op.to_s(16)}"
        end
        when 0xF000 then
        case op & 0x00FF
          when 0x0007 then @v[x] = @delay_timer
          when 0x000A then !key_press ? (@pc -= 2 && @v[x] = @keys[x]) : key_press = false
          when 0x0015 then @delay_timer = @v[x]
          when 0x0018 then @sound_timer = @v[x]
          when 0x001E then (@i += @v[x]) > 0xFFF ? @v[0xF] = 1 : @v[0xF] = 0
          when 0x0029 then @i = @v[x] * 0x5
          when 0x0033 then
            nums = "%03d" % @v[x].to_s(10)
            @memory[@i] = nums[0].to_i
            @memory[@i + 1] = nums[1].to_i
            @memory[@i + 2] = nums[2].to_i
          when 0x0055 then 0.upto(x - 1) {|i| @memory[@i + i] = @v[i]}
          when 0x0065 then 0.upto(x - 1) {|i| @v[i] = @memory[@i + i]}
          else raise Exception.new "Unknown opcode; 0x#{op.to_s(16)}"
        end
        else raise Exception.new "Unknown opcode; 0x#{op.to_s(16)}"
      end

      @delay_timer -= 1 if @delay_timer > 0
      @sound_timer -= 1 if @sound_timer > 0
      p "Play sound" if @sound_timer == 1

    end

    def do_draw_stuff(op)
      x = @v[(op & 0x0F00) >> 8]
      y = @v[(op & 0x00F0) >> 4]
      height = op & 0x000F
      @v[0xF] = 0
      0.upto(height - 1) do |yline|
        pixel = @memory[@i + yline]
        0.upto(7) do |xline|
          if (pixel & (0x80 >> xline)) != 0
            if @gpu.gfx[x + xline + ((y + yline) * 64)] == 1
              @v[0xF] = 1
            end
            @gpu.gfx[x + xline + ((y + yline) * 64)] ^= 1
          end
        end
      end
      self.draw_flag = true
    end
  end

  class GPU

    attr_accessor :gfx

    def initialize
      @gfx = [0] * 2048
    end

  end

  class Memory

    attr_accessor :memory

    def initialize
      @memory = [0] * 4096
      load_fontset
    end

    def set_program(path)
      i = 0
      File.open(path, "rb") do |io|
        while !io.eof?
          memory[i + 0x0200] = io.getbyte
          i += 1
        end
      end
    end

    def fetch(pc)
      memory[pc] << 8 | memory[pc + 1]  #opcode is 2 bytes long
    end

    private

    def load_fontset
      0.upto(79) do |i|
        memory[i] = FONTSET[i]
      end
    end

  end

  class Input
    attr_accessor :keys
    def initialize
      @keys = [0] * 16
    end
  end

  class Chip8
    include Rubygame
    include Rubygame::Events
    include Rubygame::EventActions
    include Rubygame::EventTriggers
    attr_accessor :cpu, :gpu, :mem, :input

    def self.load_game(path)
      c8 = self.new
      c8.mem.set_program(path)
      c8
    end

    def initialize
      @gpu = GPU.new
      @mem = Memory.new
      @input = Input.new
      @cpu = CPU.new(@mem.memory, @gpu, @input.keys)
      #@screen = Screen.new([64 * ZOOM, 32 * ZOOM])
      @screen = Screen.new([640, 480])
      @queue = EventQueue.new
    end

    def cycle
      opcode = mem.fetch(cpu.pc)  #fetch
      cpu.execute(opcode)
      @queue.fetch_sdl_events.each do |e|
        handle_key(e) if e.respond_to?(:key)
      end
    end

    def draw_flag
      cpu.draw_flag
    end

    def draw_screen
      0.upto(31) do |y|
        0.upto(63) do |x|
          rx = x * ZOOM
          ry = y * ZOOM
          if(@gpu.gfx[(y * 64) + x] == 0)
            @screen.draw_box_s([rx, ry], [rx + ZOOM, ry + ZOOM], [0,0,0])
          else
            @screen.draw_box_s([rx, ry], [rx + ZOOM, ry + ZOOM], [255,255,255])
          end
        end
      end
      cpu.draw_flag = false
      @screen.flip
    end

    private

    def handle_key(e)
      set = e.is_a?(Rubygame::KeyDownEvent) ? 1 : 0
      keycode = {
         49 => 0x0,  50 => 0x1,  51 => 0x2,  52 => 0x3,
        113 => 0x4, 119 => 0x5, 101 => 0x6, 114 => 0x7,
         97 => 0x8, 115 => 0x9, 100 => 0xA, 102 => 0xB,
        122 => 0xC, 120 => 0xD,  99 => 0xE, 118 => 0xF
      }[e.key]
      @input.keys[keycode] = set if keycode && set
      cpu.key_press = (set == 1)
    end
  end
end

c8 = Chip8::Chip8.load_game(ARGV[0])

Rubygame.init

while true
  c8.cycle
  if c8.draw_flag
    c8.draw_screen
  end
  #sleep 1.0/60 #60Hz
  #sleep 0.1
end
