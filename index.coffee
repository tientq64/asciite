class App extends React.Component
	constructor: (props) ->
		super props
		autoBind @
		@chrs = "
			+ * - = ~ ! ? @ # $
			% & \" ' ` ° . : , ;
			( ) { } [ ] < > / \\
			| _ ¯ … ‡ © ^ 0 1 2
			3 4 5 6 7 8 9 A B C
			D E F G H I J K L M
			N O P Q R S T U V W
			X Y Z a b c d e f g
			h i j k l m n o p q
			r s t u v w x y z
		".split " "
		@codeShiftMap =
			BackQuote: "`"
			Digit1: "1"
			Digit2: "2"
			Digit3: "3"
			Digit4: "4"
			Digit5: "5"
			Digit6: "6"
			Digit7: "7"
			Digit8: "8"
			Digit9: "9"
			Digit0: "0"
			Minus: "-"
			Equal: "="
			BracketLeft: "["
			BracketRight: "]"
			Backslash: "\\"
			Semicolon: ";"
			Quote: "'"
			Comma: ","
			Period: "."
			Slash: "/"
		@w = 47
		@h = 13
		@frames = []
		@totalDuration = 0
		@models = {}
		@modelIncrId = 0
		@tool = @chrs[0]
		@text = null
		@sel = null
		@clipboard = []
		@grid = null
		@page = null
		@item = null
		@hovItem = null
		@col = null
		@frameIndexRun = -1
		@oldPageRun = null
		@timeoutRun = 0
		@animateRun = null
		@button = 0
		@key = ""
		@g = null
		@boot()

	boot: ->
		for name from Object.getOwnPropertyNames @constructor::
			if name.startsWith "class"
				((sym) =>
					@[sym] = @[name]
					@[name] = (-> classNames @[sym] ...arguments).bind @
				) Symbol name
		return

	addFrame: (data, offset = 1) ->
		data ?= {}
		index =
			if @page?.type is "frame" then offset + @frames.indexOf @page
			else @frames.length
		frame = {
			duration: 1
			w: @w
			h: @h
			items: []
			...data
			type: "frame"
			thumbnail: null
		}
		@updateTotalDuration()
		@updatePageThumbnail frame
		@frames.splice index, 0, frame
		@updateTotalDuration()
		@setPage frame
		return

	addModel: (data) ->
		data ?= {}
		id = @modelIncrId++
		model = {
			w: 9
			h: 9
			items: []
			...data
			type: "model"
			id
			thumbnail: null
		}
		@updatePageThumbnail model
		@models[id] = model
		@setPage model
		return

	makeSel: (items = []) ->
		items: items
		hadItems: items

	removeModel: (model) ->
		if model in [@page, @tool]
			models = Object.values @models
			index = 1 + _.findIndex models, id: model.id
			fn = model is @page and @setPage or @setTool
			if model2 = models[index] or models[index - 2]
				fn model2
			else if @page.type isnt "frame"
				@setPage @frames[0]
		for frame from @frames
			if model in frame.items
				_.pull frame.items, model
				@updatePageThumbnail frame
		delete @models[model.id]
		@setState {}
		return

	removeFrame: (frame) ->
		if frame is @page
			index = 1 + @frames.indexOf frame
			if frame2 = @frames[index] or @frames[index - 2]
				@setPage frame2
			else
				@addFrame()
		_.pull @frames, frame
		@updateTotalDuration()
		return

	setPage: (page) ->
		unless @page is page
			@page = page
			@sel = null
			if page.type is "model"
				if @tool.type is "model"
					@setTool @chrs[0]
			@updateGrid page
			@setState {}, =>
				if page.type is "model"
					@refs.w.value = page.w
					@refs.h.value = page.h
				else
					@refs.w.value = page.w
					@refs.h.value = page.h
					@refs.duration.value = page.duration
				return
		return

	setTool: (tool) ->
		if tool
			@tool = tool
		@setState {}
		return

	isValidPagePos: (item, page = @page) ->
		@isValidPageXY item.x, item.y, page

	isValidPageXY: (x, y, page = @page) ->
		0 <= x < page.w and 0 <= y < page.h

	getSpreadPageItems: (page = @page) ->
		page.items.flatMap (item) =>
			switch
				when item.model
					item.model.items
						.filter (val) =>
							@isValidPagePos val, item.model
						.map (val) =>
							x: val.x + item.x
							y: val.y + item.y
							chr: val.chr
							item: item
						.filter (val) =>
							@isValidPagePos val, page
				when item.text
					@extractText item, page
				else item

	duplicateFrame: (frame, offset = 1) ->
		frame ?= @page
		@addFrame {
			...frame
			items: frame.items.map (item) => {...item}
		}, offset
		return

	convertFrameToModel: (frame = @page) ->
		minX = minY = Infinity
		maxX = maxY = -Infinity
		modelItems = []
		frameItems = []
		for item from frame.items
			if item.chr
				minX = item.x if item.x < minX
				minY = item.y if item.y < minY
				maxX = item.x if item.x > maxX
				maxY = item.y if item.y > maxY
				modelItems.push item
			else
				frameItems.push item
		if modelItems.length
			frame.items = frameItems
			@updatePageThumbnail frame
			for item from modelItems
				item.x -= minX
				item.y -= minY
			modelData =
				w: maxX - minX + 1
				h: maxY - minY + 1
				items: modelItems
			@addModel modelData
		return

	clickChr: (chr) ->
		@setTool chr
		@setState {}
		return

	mouseDownEnterUpCol: (col, isFirst) ->
		dx = @col and col.x - @col.x or 0
		dy = @col and col.y - @col.y or 0
		@col = col
		@item = @col.items[0]
		switch @button
			when 1
				switch @key
					when "Alt"
						unless @text or @page.type is "model"
							@text =
								x: col.x
								y: col.y
								text: ""
							setTimeout @refs.textarea.focus.bind @refs.textarea
					when "Shift"
						if isFirst
							@sel ?= @makeSel()
							@sel.x = col.x
							@sel.y = col.y
							@sel.hadItems = @sel.items
						@sel.x0 = Math.min col.x, @sel.x
						@sel.y0 = Math.min col.y, @sel.y
						@sel.x1 = Math.max col.x, @sel.x
						@sel.y1 = Math.max col.y, @sel.y
						items = []
						for y in [@sel.y0..@sel.y1] by 1
							for x in [@sel.x0..@sel.x1] by 1
								for item from @grid[y][x].items
									{item} = item if item.item
									unless item in items
										items.push item
						@sel.items = _.union @sel.hadItems, items
					else
						if @sel
							for item from @sel.items
								item.x += dx
								item.y += dy
						else if @text
						else
							if @tool.type is "model"
								if item = col.orgItems.find (v) => v.model is @tool
									_.pull @page.items, item
								item =
									x: col.x - @tool.w // 2
									y: col.y - @tool.h // 2
									model: @tool
							else
								if item = col.orgItems.find (v) => v.chr
									_.pull @page.items, item
								item =
									x: col.x
									y: col.y
									chr: @tool
							@page.items.push item
						@updatePageThumbnail()
			when 2
				if @item
					@setTool @item.chr
					@setState {}
			when 3
				if @item
					_.pull @page.items, @item.item or @item
					@updatePageThumbnail()
			else
				switch @key
					when "Shift"
						@hovItem = @item
		@updateGrid()
		return

	mouseDownModel: (model) ->
		switch @button
			when 1
				if @page.type is "model" or @tool is model
					@setPage model
				else
					@setTool model
			when 3
				@removeModel model
		return

	mouseDownFrame: (frame) ->
		switch @button
			when 1
				@setPage frame
			when 3
				@removeFrame frame
		@setState {}
		return

	mouseEnterCol: (col) ->
		@mouseDownEnterUpCol col
		return

	onWheelGrid: (event) ->
		unless @tool.type
			index = @chrs.indexOf @tool
			index = (index + Math.sign event.deltaY) %% @chrs.length
			@setTool @chrs[index]
			@setState {}
		return

	onChangePageW: (event) ->
		if event.target.validity.valid
			@page.w = event.target.valueAsNumber
			@updatePageThumbnail()
			@updateGrid()
		return

	onChangePageH: (event) ->
		if event.target.validity.valid
			@page.h = event.target.valueAsNumber
			@updatePageThumbnail()
			@updateGrid()
		return

	onChangePageDuration: (event) ->
		if event.target.validity.valid
			@page.duration = event.target.valueAsNumber
			@updateTotalDuration()
		return

	onChangeTextarea: (event) ->
		@text.text = event.target.value
		@updateGrid()
		return

	onBlurTextarea: (event) ->
		if @text
			text = @formatTextText @text.text.trimEnd()
			if text
				item =
					x: @text.x
					y: @text.y
					text: text
				@page.items.push item
			setTimeout =>
				@text = null
				return
			@refs.textarea.value = ""
			@updatePageThumbnail()
			@updateGrid()
		return

	onMouseDown: (event) ->
		@button = event.which
		return

	onMouseUp: ->
		if @sel
			@sel.hadItems = null
			@sel = null unless @sel.items.length
		@button = 0
		@mouseDownEnterUpCol @col if @col
		return

	onKeyDown: (event) ->
		unless event.repeat
			@updateKey event
			{key, ctrlKey, altKey, metaKey} = event
			activeEl = document.activeElement
			isInput = activeEl.localName in ["input", "textarea", "select"]
			if not ctrlKey and not altKey and not metaKey and key.length is 1
				if key in @chrs
					@setTool key
			else
				switch @key
					when "Shift"
						@hovItem = @item
					when "Escape"
						if isInput
							activeEl.blur()
						else if @sel
							@sel = null
					when "Tab"
						if isInput
							if activeEl is @refs.textarea
								event.preventDefault()
					when "Ctrl+C", "Ctrl+X"
						unless isInput
							if @sel
								minX = minY = Infinity
								for item from @sel.items
									minX = item.x if item.x < minX
									minY = item.y if item.y < minY
								@clipboard = @sel.items.map (item) => {
									...item
									x: item.x - minX
									y: item.y - minY
								}
								if @key is "Ctrl+X"
									_.pullAll @page.items, @sel.items
									@sel = null
								@updatePageThumbnail()
					when "Ctrl+V"
						unless isInput
							if @clipboard.length
								items = @clipboard.map (item) => {...item}
								@page.items.push ...items
								@sel = @makeSel items
								@updatePageThumbnail()
					when "Ctrl+S"
						event.preventDefault()
						localStorage.asciite = @exportData yes
					when "Ctrl+Shift+S"
						event.preventDefault()
						@saveAsFile @exportData(), "edit-#{Date.now()}.json"
					when "Ctrl+Shift+Alt+S"
						event.preventDefault()
						@saveAsFile @publishData(), "film-#{Date.now()}.json"
			@updateGrid()
		return

	onKeyUp: ->
		@key = ""
		@hovItem = null
		@updateGrid()
		return

	onBlur: (event) ->
		if event.target is event.currentTarget
			@onMouseUp()
			@onKeyUp()
		return

	onContextMenu: (event) ->
		event.preventDefault()
		return

	formatTextText: (text) ->
		text.replace /\.{3}/g, "…"

	extractText: (item, page, hasCursor) ->
		items = []
		{x, y, text} = item
		text = @formatTextText text
		text += "|" if hasCursor
		for chr from text
			if chr is "\n"
				{x} = item
				y++
			else if /\s/.test chr
				x++
			else
				val =
					x: x++
					y: y
					chr: chr
					item: item
				items.push val
		val.cursor = yes if hasCursor
		items

	exportData: (useLZString) ->
		models = Object.values @models
		frames = @frames.map (frame) => [
			frame.items.map (item) => [
				item.x
				item.y
				if item.text then "'#{item.text}"
				else if item.model then models.indexOf item.model
				else item.chr
			]
			frame.duration
		]
		models = models.map (model) => [
			model.items.map (item) => [
				item.x
				item.y
				item.chr
			]
			model.w
			model.h
		]
		data = JSON.stringify [models, frames]
		data = LZString.compress data if useLZString
		data

	publishData: ->
		models = []
		frames = @frames.map (frame) => [
			frame.items.map (item) => [
				item.x
				item.y
				if item.text then "'#{item.text}"
				else if item.model
					index = models.indexOf item.model
					if index < 0
						models.push item.model
						models.length - 1
					else index
				else item.chr
			]
			frame.duration
		]
		models = models.map (model) => [
			model.items.map (item) => [
				item.x
				item.y
				item.chr
			]
			model.w
			model.h
		]
		JSON.stringify [models, frames]

	importData: (data, useLZString) ->
		if data
			data = LZString.decompress data if useLZString
			data = JSON.parse data
			@modelIncrId = data[0].length
			@models = {}
			for modelData, i in data[0]
				model =
					type: "model"
					id: i
					w: modelData[1]
					h: modelData[2]
					items: modelData[0].map (itemData) =>
						x: itemData[0]
						y: itemData[1]
						chr: itemData[2]
					thumbnail: null
				@updatePageThumbnail model
				@models[i] = model
			@frames = data[1].map (frameData) =>
				frame =
					type: "frame"
					duration: frameData[1]
					w: @w
					h: @h
					items: frameData[0].map (itemData) =>
						item =
							x: itemData[0]
							y: itemData[1]
						if typeof itemData[2] is "number"
							item.model = @models[itemData[2]]
						else if itemData[2].length is 1
							item.chr = itemData[2]
						else
							item.text = itemData[2][1..]
						item
				@updatePageThumbnail frame
				frame
			@updateTotalDuration()
			yes

	saveAsFile: (data, filename) ->
		blob = new Blob [data]
		url = URL.createObjectURL blob
		el = document.createElement "a"
		el.href = url
		el.download = filename
		el.click()
		URL.revokeObjectURL url
		return

	updateKey: (event) ->
		{key, code} = event
		@key = ""
		if key in ["Control", "Shift", "Alt", "Meta"]
			@key = key is "Control" and "Ctrl" or key
		else
			@key += "Ctrl+" if event.ctrlKey
			@key += "Shift+" if event.shiftKey
			@key += "Alt+" if event.altKey
			@key += "Meta+" if event.metaKey
			key = @codeShiftMap[code] or key if event.shiftKey
			key = key.toUpperCase() if key.length is 1
			@key += key
		return

	updateTotalDuration: ->
		@totalDuration = _.sumBy @frames, "duration"
		@setState {}
		return

	updatePageThumbnail: (page = @page) ->
		@g.canvas.width = page.w
		@g.canvas.height = page.h * 2
		@g.clearRect 0, 0, page.w, page.h * 2
		items = @getSpreadPageItems page
		@g.fillStyle = "#fff"
		for item from items
			@g.fillRect item.x, item.y * 2, 1, 2
		page.thumbnail = @g.canvas.toDataURL()
		return

	updateGrid: (page = @page) ->
		@grid = _.times page.h, (y) => _.times page.w, (x) =>
			x: x
			y: y
			items: []
			orgItems: []
			bgColor: "black"
			color: "white"
		items = @getSpreadPageItems page
		if @text
			items.push ...@extractText @text, page, yes
		for item from page.items
			@grid[item.y]?[item.x]?.orgItems.unshift item
		for item from items
			@grid[item.y]?[item.x]?.items.unshift item
		for row from @grid
			for col from row
				if @hovItem
					if col.items.some (v) => v.item is @hovItem.item
						col.color = "gray"
				if @sel
					if @sel.hadItems
						if @sel.x0 <= col.x <= @sel.x1 and @sel.y0 <= col.y <= @sel.y1
							col.bgColor = "dark"
					for item from col.items
						{item} = item if item.item
						if item in @sel.items
							col.color = "blue"
							break
				if col.items.some (v) => v.cursor
					col.color = "red"
		@setState {}
		return

	run: (frame = @page) ->
		@sel = null
		if @timeoutRun
			@frameIndexRun = -1
			@timeoutRun = clearTimeout @timeoutRun
			@animateRun.finish()
			@animateRun = null
			@setPage @oldPageRun
		else
			@oldPageRun = @page
			@frameIndexRun = if frame.type is "frame" then @frames.indexOf frame else 0
			duration = _.sumBy @frames[@frameIndexRun..], "duration"
			start = @totalDuration - duration
			@animateRun = @refs.durationRun.animate [
				width: "#{start * 50}px"
			,
				width: "#{@totalDuration * 50}px"
			],
				duration: duration * 1000
				easing: "steps(#{_.round duration / .1, 1}, start)"
			@handleRun()
		@updateGrid()
		return

	handleRun: ->
		if frame = @frames[@frameIndexRun++]
			@setPage frame
			@timeoutRun = setTimeout @handleRun, frame.duration * 1000
			@setState {}
		else @run()
		return

	componentDidMount: ->
		@g = @refs.canvas.getContext "2d"
		addEventListener "mousedown", @onMouseDown, yes
		addEventListener "mouseup", @onMouseUp, yes
		addEventListener "keydown", @onKeyDown, yes
		addEventListener "keyup", @onKeyUp, yes
		addEventListener "blur", @onBlur, yes
		addEventListener "contextmenu", @onContextMenu, yes
		@importData localStorage.asciite, yes
		@updateTotalDuration()
		if frame = @frames[0] then @setPage frame
		else @addFrame()
		return

	render: ->
		<div>
			{if @page
				<div className="column full black">
					<div className="col row">
						<div className="col column p-5">
							<div className="flex center middle" style={minHeight: 414}>
								<div className="relative text-mono leading-1">
									<div
										className="grid text-bold dark1"
										style={
											gridTemplateColumns: "repeat(#{@page.w}, 1fr)"
											fontSize: @timeoutRun and 20 or 24
										}
										onWheel={@onWheelGrid}
									>
										{@grid.map (row) => row.map (col) =>
											<div
												className={classNames [
													"dark0"
													col.bgColor
													"text-#{col.color}"
													"bound-black-1": not @timeoutRun and col.bgColor isnt "dark"
												]}
												onMouseDown={=> @mouseDownEnterUpCol col, yes}
												onMouseEnter={=> @mouseEnterCol col}
											>
												{col.items[0]?.chr or "\xa0"}
											</div>
										}
									</div>
									{if not @timeoutRun
										<div className="full opacity-25 no-event">
											<div className="absolute l-25 t-0 -trans-50 shape-dot-gray"/>
											<div className="absolute l-50 t-0 -trans-50 shape-dot-gray"/>
											<div className="absolute l-75 t-0 -trans-50 shape-dot-gray"/>
											<div className="absolute l-0 t-50 -trans-50 shape-dot-gray"/>
											<div className="absolute l-25 t-50 -trans-50 shape-dot-gray"/>
											<div className="absolute l-50 t-50 -trans-50 shape-dot-gray"/>
											<div className="absolute l-75 t-50 -trans-50 shape-dot-gray"/>
											<div className="absolute l-100 t-50 -trans-50 shape-dot-gray"/>
											<div className="absolute l-25 t-100 -trans-50 shape-dot-gray"/>
											<div className="absolute l-50 t-100 -trans-50 shape-dot-gray"/>
											<div className="absolute l-75 t-100 -trans-50 shape-dot-gray"/>
										</div>
									}
								</div>
							</div>
							<div className="col column">
								<div className="row middle pt-5 pb-3">
									<i className="fa fa-cubes mr-4"/>
									<div className="col">Mô hình</div>
									<button onClick={=> @addModel()}>
										<i className="fa fa-plus mr-4"/> Thêm
									</button>
								</div>
								<div className="col scroll">
									<div className="grid-12 gap-2" style={gridAutoRows: 32}>
										{_.map @models, (model) =>
											<div
												className={classNames [
													"column center middle text-center dark"
													"blue": @page is model
													"bound-blue": @tool is model
												]}
												onMouseDown={=> @mouseDownModel model}
											>
												<img src={model.thumbnail}/>
											</div>
										}
									</div>
								</div>
							</div>
						</div>
						<div className="p-5 column" style={width: 390}>
							<div className="col-6 scroll grid-10 text-mono text-lg text-bold">
								{@chrs.map (chr) =>
									<div
										className={classNames [
											"flex center middle"
											"text-blue": @tool is chr
										]}
										onClick={=> @clickChr chr}
									>
										{chr}
									</div>
								}
							</div>
							<div className="col-6 column">
								<div className="row pb-3">
									<legend className="mt-5">
										<span>
											<i className="fa fa-list mr-4"/> Thuộc tính
										</span>
									</legend>
								</div>
								<div className="col scroll">
									<div className="row wrap middle fields">
										<div className="col-6">Chiều dài</div>
										<input
											ref="w"
											className="col-6 dark"
											type="number"
											readOnly={@page.type is "frame"}
											min={1}
											max={@w}
											required
											onChange={@onChangePageW}
										/>
										<div className="col-6">Chiều rộng</div>
										<input
											ref="h"
											className="col-6 dark"
											type="number"
											readOnly={@page.type is "frame"}
											min={1}
											max={@h}
											required
											onChange={@onChangePageH}
										/>
										{if @page.duration then [
											<div className="col-6">Thời lượng</div>
											<form className="col-6 dark input-group">
												<label>
													<input
														ref="duration"
														type="number"
														min={.1}
														max={60}
														step={.1}
														required
														onChange={@onChangePageDuration}
													/>
													<span>giây</span>
												</label>
											</form>
										]}
									</div>
								</div>
							</div>
						</div>
					</div>
					<div className="col-0 column p-5">
						<div className="row middle pb-3">
							<i className="fa fa-images mr-4"/>
							<div className="col">Khung hình</div>
							<div className="col-0 group">
								<button
									disabled={@page.type isnt "frame"}
									onClick={=> @convertFrameToModel()}
								>
									<i className="fa fa-cube mr-4"/> Chuyển thành mô hình
								</button>
								<button
									disabled={@page.type isnt "frame"}
									onClick={=> @duplicateFrame null, 0}
								>
									<i className="fa fa-copy mr-4"/> Nhân đôi trái
								</button>
								<button
									disabled={@page.type isnt "frame"}
									onClick={=> @duplicateFrame()}
								>
									<i className="fa fa-copy mr-4"/> Nhân đôi phải
								</button>
								<button
									disabled={@page.type isnt "frame"}
									onClick={=> @addFrame null, 0}
								>
									<i className="fa fa-plus mr-4"/> Thêm trái
								</button>
								<button
									disabled={@page.type isnt "frame"}
									onClick={=> @addFrame()}
								>
									<i className="fa fa-plus mr-4"/> Thêm phải
								</button>
								<button
									onClick={=> @run()}
								>
									<i className="fa fa-#{@timeoutRun and 'pause' or 'play'} mr-4"/>
									{@timeoutRun and "Dừng" or "Phát"}
								</button>
							</div>
						</div>
						<div className="col column top pb-2 scroll-x">
							<div className="row relative mb-2">
								<div
									ref="durationRun"
									className="absolute mb-2 red h-100"
								/>
								{_.times Math.max(@totalDuration + 1, innerWidth / 50), (i) =>
									<small
										className="text-center -transx-50"
										style={width: 50}
										children={i}
									/>
								}
							</div>
							<div className="row divide-x-black">
								{@frames.map (frame, i) =>
									<div
										className={classNames [
											"column center middle py-3 no-events"
											@page is frame and "blue z-1" or "dark no-scroll"
										]}
										style={width: frame.duration * 50}
										onMouseDown={=> @mouseDownFrame frame}
									>
										<img src={frame.thumbnail}/>
										<small>{frame.duration}</small>
									</div>
								}
							</div>
						</div>
					</div>
				</div>
			}
			<canvas ref="canvas" hidden/>
			<textarea
				ref="textarea"
				onChange={@onChangeTextarea}
				onBlur={@onBlurTextarea}
			/>
		</div>

ReactDOM.render <App/>, appEl
