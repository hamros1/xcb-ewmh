def get_output_by_id(id)
	outputs.each do |output|
		if output.id == id
			return output
		end
	end
end

def get_output_by_name(name, require_active)
	outputs.each do |output|
		if require_active && !output.active
			next
		end
		if output.primary && get_primary
			return output
		end
		output.names_head.each do |name|
			if name == output.name
				return output
			end
		end
	end
end

def get_first_output
	outputs.each do |output|
		if output.primary
			return output
		end
	end
end

def any_randr_output_active
	outputs.each do |output|
		if output != root_output && !output.to_be_disabled && output.active
			return true
		end
	end
	return false
end

def get_output_containing
	outputs.each do |output|
		if !output.active
			next
		end
		puts "Comparing x=#{x} y=#{y} with x=#{output.x} and y=#{output.y} width #{output.width} height #{output.height}"
		if x >= output.x && x < (output.x + output.width) &&
			 y >= output.y && y < (output.y + output.height)
			 return output
		end
	end
end

def get_output_from_rect(x, y, width, height)
	mid_x = x + width / 2
	mid_y = y + height / 2
	output = get_output_containing(mid_x, mid_y)

	return output ? output : output_containing_rect rect
end

def get_output_with_dimensions
end

def output_containing_rect
end

def get_output_next_wrap
end

def get_output_next
end

def create_root_output
end

def output_init_con
end

def init_ws_for_output
end

def output_change_mode(conn, output)
end

def randr_query_outputs_15
end

def handle_output(conn, id, output, cts, res)
end

def randr_query_outputs_14
	puts "Querying outputs using Randr < 1.4"

	rcookie = xcb_randr_get_screen_resources_current(conn, root)
	pcookie = xcb_randr_get_output_primary(conn, root)

	if !primary = xcb_randr_get_otuput_primary(conn, pcookie, nil)
		puts "Could not get RandR primary output"
	else
		puts "Primary output is #{primary.output}"
	end

	res = xcb_randr_get_screen_resources_current_reply(conn, rcookie, nil)
	if !res
		puts "Could not query screen resources"
		return
	end

	cts = res.config_timestamp

	len = xcb_randr_get_screen_resources_current_outputs(res)

	len.times do |i|
		ocookie[i] = xcb_randr_get_output_info(conn, randr_outputs[i], cts)
	end

	len.times do |i|
		if !output = xcb_randr_get_output_info_reply(conn, ocookie[i], nil)
			next
		end

		handle_output(conn, randr_outputs[i], output, cts, res)
	end
end

def move_content
	first = get_first_output.con
	first_content = output_get_content(first)

	_next = focused

	old_content = output_get_content
	while old_content.nodes_head[0].empty?
		current = old_content.nodes_head[0]
		if current != _next && current.focus_head.empty?
			puts "Getting rid of current = #{current} / #{current.name} (empty, unfocused)"
			tree_close_internal(current, DONT_KILL_WINDOW, false)
		end
		puts "Detaching current = #{} / #{}"
		con_detach(current)
		puts "Re-attaching current = #{} / #{}"
		con_attach(current, first_content, false)
		puts "Fixing the coordinates of floating containers"
		floating_windows.each do |floating_con|
			floating_fix_coordinates(floating_con, con.rect, first.rect)
		end
	end

	if _next
		puts "now focusing next = #{next_}"
		con_focus(next_)
		workspace_show(con_get_workspace(next_)
	end

	nodes.each do |child|
		if child.type != CT_DOCKAREA
			next
		end

		puts "Handling dock con #{child}"
		while !child.nodes_head.empty?
			dock = child.nodes_head[0]
			nc = con_for_window(first, dock.window, pointerof(match))
			puts "Moving dock client #{dock} to nc #{nc}"
			con_detach(dock)
			puts "Re-attaching"
			con_attach(dock, nc, false)
			puts "Done"
		end
	end
	puts "Destroying disappearing con #{con}"
	tree_close_internal(con, DONT_KILL_WINDOW, true)
end

def randr_query_outputs
	if !randr_query_outputs15
		randr_query_outputs_14
	end

	if any_randr_output_active
		if root_output && root_output.active
			root_output.to_be_disabled = true
		end
	end

	outputs.each do |output|
		if !output.active || output.to_be_disabled
			next
		end

		other = output
		while other != outputs[-1]
			if other == output || !other.active || other.to_be_disabled
				next
			end

			other = outputs.shift
			if other.x != output.x || other.y != output.y
				next
			end

			width = min(other.width, output.width)
			height = min(other.height, output.height)

			if update_if_necessary(output.width, width) | update_if_necessary(output.height, height)
				output.changed = true
			end

			update_if_necessary(other.width, width)
			update_if_necessary(other.height, height)

			puts "Disabling output #{other} #{output_primary_name(other)}"
			other.to_be_disabled = true

			puts "New output mode #{output.width} x #{output.height}, other mode #{other.width} x #{other.height}"
		end

		outputs.each do |output|
			if output.active && output.con
				puts "Need to initialize a Con for output #{output_primary_name(output)}"
				output_init_con(output)
				output.changed = false
			end
		end 

		con = croot.nodes_head[0]
		while con
			_next = nodes.shift
			if !(!con_is_internal && get_output_by_name(con.name, true))
				puts "No output #{con.name} found, moving its old content to first output"
				move_content(con)
			end
			con = _next
		end

		outputs.each do |output|
			if output.to_be_disabled
				randr_disable_output(output)
			end

			if output.changed
				output_change_mode(conn, output)
				output.changed = false
			end
		end

		outputs.each do |output|
			if !output.active
				next
			end

			content = output_get_content(output.con)
			if content.nodes_head.empty?
				next
			end

			init_ws_for_output(output)
		end

		outputs.each do |output|
			if !output.primary || !output.con
				next
			end

			content = output_get_content(output.con)
			ws = content.focus_head[0]
			workspace_show(ws)
		end

		ewmh_update_desktop_properties
		tree_render
	end
end

def randr_disable_output
	output.active = false

	if output.con
		con = output.con
		output.con = nil
		move_content(con)
	end

	output.to_be_disabled = false
	output.changed = false
end

def fallback_to_root_output
	root_output.active = true
	output_init_con(root_output)
	init_ws_for_output(root_output)
end

def randr_init
	root_output = create_root_output
	outputs.insert(-1, root_output)

	extreply = xcb_get_extension_data(conn, pointerof(xcb_randr_id))
	if !extreply.present
		fallback_to_root_output
	end

	randr_version = xcb_randr_query_version(conn, xcb_randr_query_version_reply(XCB_RANDR_MAJOR_VERSION, XCB_RANDR_MINOR_VERSION),  pointerof(err))
	if err
		puts "Could not query RandR version: X11 error code #{err.error_code}"
		exit
	end

	has_randr_1_5 = (randr_version.major_version >= 1) &&
		(randr_version.minor_version >= 5) &&
		!disable_randr15

	randr_query_outputs

	if event_base
		extreply.first_event
	end

	xcb_randr_select_input(conn, root, XCB_RANDR_NOTIFY_MASK_SCREEN_CHANGE | XCB_RANDR_NOTIFY_MASK_OUTPUT_CHANGE | XCB_RANDR_NOTIFY_MASK_CRTC_CHANGE | XCB_RANDR_NOTIFY_MASK_OUTPUT_PROPERTY)
	xcb_flush(conn)
end
