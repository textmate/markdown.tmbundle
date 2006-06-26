class String
	
	def add_newline()
		if self !~ /\n$/m
			self + "\n"
		else
			self
		end
	end
	
end


module Markdown
	
	class ListLine
		attr_accessor :line, :indent, :str

		
		def initialize(line, indent, str)
			@line = line
			@indent = indent
			@str = str
			@inserts = []
		end
		
		
		def [](arg)
			if arg.kind_of?(Range)
				# adjust the range by the indent
				if (arg.begin >= 0 and arg.begin < @indent.length) and (arg.end >= 0 and arg.end < @indent.length)
					return ""
				end
				
				newbegin = if arg.begin >= 0 then [arg.begin - @indent.length, 0].max() else arg.begin end
				newend = if arg.end >= 0 then [arg.end - @indent.length, 0].max() else arg.end end
				return @str[Range.new(newbegin, newend, arg.exclude_end?)]
			elsif arg.kind_of?(Integer)
				if arg < 0
					return @str[arg]
				else
					return @str[[arg - @indent.length(), 0].max()]
				end
			else
				return @str[arg]
			end
		end
		
		
		def insert(pos, insert)
			@inserts << [pos, insert]
		end
		
		
		def to_s()
			str = @str
			@inserts.each { |i| str = str.insert(i[0], i[1]) }
			str
		end		
	end
	
	
	class List
		class SubList < StandardError
		end

		
		attr_accessor :line, :indent, :numbered
		
		@@sublistregex = /^\s+([0-9]+\.|\*)\s/
		
		def initialize()
			@entries = []
		end
		
		
		def add(entry)
			@entries << entry
			self
		end
		
		
		def <<(entry)
			add(entry)
			self
		end
		
		
		def length()
			@entries.inject(0) { |t, e| t + e.inject(0) { |t, l| if l.kind_of?(List) then t + l.length else t + 1 end } }
		end

				
		def [](index)
			@entries[index]
		end
		
		
		def map!(&block)
			@entries.each() do |e|
				e.each() do |l|
					if l.kind_of?(ListLine)
						l.str = yield(l.str)
					else
						l.map!(&block)
					end
				end
			end
			
			self
		end
		
		
		# breaks the list at line, pos in the original input
		# inserts insert at the break point and filters everything
		# else through block
		def break(line, pos, insert = "$0", &block)
			curline = 0
			@entries.each_index() do |i|
				@entries[i].each_index do |li|
					l = @entries[i][li]
					if l.kind_of?(ListLine)
						if l.line == line
							breakentry = @entries[i]
							breakline = @entries[i][li]
							firstpart = breakentry[0...li] << ListLine.new(-1, breakline.indent, (breakline[0...pos].add_newline()))
							secondpart = [ListLine.new(-1, breakline.indent, breakline[pos..-1].lstrip().add_newline())] + breakentry[li+1..-1]
							secondpart[0].insert(0, " " + insert)
							
							@entries = @entries[0...i] + [firstpart, secondpart] + @entries[i+1..-1]
							break
 						end
					elsif l.line <= line and l.line + l.length >= line
						l.break(line - l.line, pos)
					end
				end
			end

			if block
				self.map!(&block)
			end
			
			self
		end
		
		
		# parses the list into a full structure
		def List.parse(str, line = 0)
			list = List.new()
			list.indent = str[/^(\s*)/, 1].to_s()
			list.numbered = /^\s*([0-9])/.match(str.to_a[0])
			list.line = line
			itemregex = /^(#{Regexp.escape(list.indent)}#{if list.numbered then "[0-9]+\\." else "\\*" end})(\s.*)/

			entry = []
			linenumber = -1
			begin
				lines = str.to_a()
				lines.each_index() do |i|
					line = lines[i]
					linenumber += 1
					
					# we might be in an indented sublist, if the indent goes down, return the list and the remainder
					if list.indent.length > 0 && line[/^(\s*)/, 1].to_s.length < list.indent.length
						list << entry
						return [list, lines[i..-1].join()]
					end
					
					if itemregex.match(line)
						if entry.length > 0
							list << entry
						end
						entry = [ListLine.new(linenumber, $1, $2 + "\n")]
					else
						if @@sublistregex.match(line)
							sublist, str = List.parse(lines[i..-1].join(), i)
							entry << sublist
							linenumber += sublist.length - 1
							raise SubList
						else
							entry << ListLine.new(linenumber, "", line)
						end
					end
				end
				list << entry
			rescue SubList
				retry
			end
			
			list
		end


		def to_s()
			str = ""
			@entries.each_index() do |i|
				str << @indent
				if @numbered
					str << "#{i+1}."
				else
					str << "*"
				end
				
				str << @entries[i].map { |e| e.to_s() }.join()
			end
			
			str
		end
	end
	
end
