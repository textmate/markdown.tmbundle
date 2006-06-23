# properly escapes a string for insertion as a snippet
module Markdown
# Takes a raw markdown list and returns an array containg information about the list.
# Specifically, [indent (str), numbered (boolean), spaced (boolean), nextitemregex (regular expression that matches a single list item)]
	def Markdown.get_list_type(list)
		numbered = false
		spaced = false
		indent = ""

		check = /^(\s*)([0-9]|\*)/.match(list)
		if !check
			return nil
		end

		indent = check[1]
		if check[2] =~ /[0-9]/
			numbered = true
		end
	
		nextitemregex = Regexp.new("^(#{Regexp.escape(indent)}#{if numbered then '[0-9]+\\.' else '\\*' end}) (.*)$")
		lastline = list[/^(.*)(\n|$)/]
		list.split(/\n/)[1..-1].each() do |line|
			if nextitemregex.match(line)
				if lastline =~ /^\s*$/
					spaced = true
				end
				break
			end
		
			lastline = line
		end
	
		return [indent, numbered, spaced, nextitemregex]	
	end


	# returns a list as an array, without initial indent or bullets/numbers given the list
	# and the regular expression from get_list_type
	def Markdown.split_list(list, regex)
		list = list.split(/\n/)
		cur = regex.match(list[0])[2]
		newlist = []
		linestarts = [[0, $1.length()]]
		(1..list.length() - 1).each do |i|
			line = list[i]
			if regex.match(line)
				newlist << cur.chomp()
				linestarts << [i, $1.length()]
				cur = $2  # set implicitly by the regex match in the if condition
			else
				cur += "\n#{line}"
			end
		end
		newlist << cur.chomp()
	
		linestarts.zip(newlist)
	end
end
