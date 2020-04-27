macroScript VertexAnimationExportTool category:"VJ"
tooltip:"VertexAnimationExportTool"
(
  



	ResumeEditing()
	escapeEnable = true
	/*********************************************************************************************************
	
	Vertex Animation Tools
	Written by Jonathan Lindquist at Epic Games
	
	Modified by VJ --2020.4.24

	*********************************************************************************************************/
	
	global default_Morph_FloaterOpen=True
	global default_SelectionSequenceRolloutOpen=False
	global Morph_Floater
	global targetMorphUV=2
	
	fn fixUVNames polyToFix = (
		for i = 1 to (polyop.getNumMaps polyToFix) do (ChannelInfo.NameChannel polyToFix 3 i ("UVChannel_" + i as string))
	)

	fn reinitRolloutSize = (
		mR=if default_Morph_FloaterOpen == true then 340 else 28
		kR=if default_SelectionSequenceRolloutOpen == true then 88 else 28
		Morph_Floater.Size=[175,(mR+kR)]

	)
	fn selectionModelCheck myModel = (
			isvalidnode myModel and superclassof myModel == GeometryClass 
	)
	

	fn checkUnitsSetup = (
		if (units.SystemType!=#Centimeters)  
		then (
			messagebox "请修改系统单位为:厘米.\r\rGo to ''Customize'' in the main tool bar, ''Units Setup'' then press the \r''System Unit Setup'' button and finally choose ''Centimeters'' from the dropdown list."
			false
		) 
		else (
			true
		)
	)			
	try DestroyDialog ::TexMorphRollout	catch()
	rollout TexMorphRollout "顶点动画导出工具" (

		on TexMorphRollout rolledUp state do (
			default_Morph_FloaterOpen=state 
			reinitRolloutSize()
			
			
		)
		
		/*************************************************************************************************************************************************
		base function library
		***************************************************************************************************************************************************/
		
			
			function round num = (
				remainder = num- (floor num)
				if (remainder >= .5) then (fnum= ceil num) else (fnum = floor num) 
				fnum
			)
			fn clamp num cMin cMax = (
				/*Chris Wood*/
				result = num
				if result < cMin
				then result = cMin
				else (
					if result > cMax
					then result = cMax
				)
				return result
			)
			fn clampVector V vMin vMax =(
				tempvector=[0.0,0.0,0.0] 
				for a=1 to 3 do (
					tempvector[a]=clamp V[a] vMin vMax
				)
				tempvector
			)
				
			fn absoluteValVector V= (
				tempvector=[0.0,0.0,0.0] 
				for a=1 to 3 do (
					tempvector[a]=abs V[a] 
				)
				tempvector
			)

			fn spreadOutSelection = if selection.count>0 do (for i=1 to selection.count do selection[i].position= [80*i,0,0])
			
		/*************************************************************************************************************************************************
		End base function library
		***************************************************************************************************************************************************/
			global originalMesh -- =$husky_arms001
			global copyBaseMesh 
			global numberofVerts 
			global originalMeshVertPositions = #()
			global MorphTargetArray
			global Morph_Floater
			global internalArrayOfStaticBaseMeshes=#()
			global vertexUVPosition=#()
			global MorphNormalArray=#()
			global MorphVertOffsetArray=#()
			global MorphTargetProgressPercentage = 0.0
			global masterMorphArray=#()
			global noMeshesArray=#(" 没有模型可以执行" as string)
			--outExrParam
			global CompressionType=0
			global OutputType=1
			global OutputFormat=0

			
			label lb1 "—————————————by VJ—————————————"
			group "动画设置"
			(
				spinner spinnerAnimationRangeStart "开始帧" type:#integer range:[0,1000000,animationRange.start] 
				spinner spinnerAnimationRangeEnd "结束帧" type:#integer range:[0,1000000,animationRange.end] 
				spinner spinnerAnimationRate "间隔" type:#integer range:[0,1000000,0] 
				dropdownlist ddlTextureCoordinate "使用UV通道" items:#("2","3","4","5","6","7","8") tooltip:"使用第几个套UV采样"
				checkbox captureAbsolutePositions "捕获绝对位置" checked:false tooltip:"使用它来捕获顶点的绝对位置。此数据与变形目标材质函数一起使用时，要求在材质函数的世界位置偏移量输出中减去世界位置，并在将其用于世界位置偏移量节点之前将actor位置添加回结果中。 此功能可能会减小变形目标的有效范围，但将允许用户生成其他高级效果。”"
				
			)
			group "EXR格式"
			(

			   dropdownlist ddlCompressionType "压缩格式" items:#("无压缩","行程编码（RLE）","ZLIB压缩，一次扫描一条","ZLIB压缩，以16条扫描线为块","基于PIZ的小波压缩","有损24位浮点压缩","有损4 x 4像素块压缩","有损4 x 4像素块压缩（固定速率）") tooltip:"选择压缩模式"
			   dropdownlist ddlOutputType "渲染通道" items:#("RGB","RGBA","单通道","XYZ（仅G缓冲通道）","XY（仅G缓冲通道）","紫外线（仅G缓冲通道）") tooltip:"选择渲染通道"
			   dropdownlist ddlOutputFormat "输出格式" items:#("FLOAT32","FLOAT16","INT32") tooltip:"选择输出格式"
			   on ddlCompressionType selected item do
				   (
					   CompressionType=item-1
					   --print(CompressionType)
					  -- print(ddlCompressionType.selected)
				   )
			   on ddlOutputType selected item do
				   (
					   if item ==1 then OutputType=1
					   else if item ==2 then OutputType=0
					   else OutputType=item-1	
					  -- print OutputType				   
					   --print(ddlOutputType.selected)
				   )
			   on ddlOutputFormat selected item do
				   (
					   OutputFormat=item-1
					  -- print(ddlOutputFormat.selected)
				   )
			)
			
			button BakeBtn "开始烘培" height:80 width:250 --images:#(GetDir #maxSysIcons+"\CAT_CATMode_a.bmp", undefined, 1,1,1,1,1 ) iconSize:[200,100]
			
			
			button help "帮助"
			

			
			fn msgBreak = (
					format "*** % ***\n" (getCurrentException())
					messagebox ("错误 \r\r''" + getCurrentException() + "''")
			)
			
			fn getvertCount originalMesh = (numberofVerts = getNumVerts originalMesh)
			
			fn checkmodel model =( isvalidnode model and superclassof model == GeometryClass ) --and (getvertCount model>0)
			
			fn updateProgAmount i myArrayCount = (
				MorphTargetProgressPercentage=((i as float/myArrayCount as float)*100.0)
				progressUpdate MorphTargetProgressPercentage   
				if MorphTargetProgressPercentage == 100.0 do progressEnd()
				if getProgressCancel() == true do (
					progressEnd()
				) -- returns true if cancelled
			)
			
			
			fn getTheVertexNormal processObject vertexIndex = ( 
				normal = [0.0,0.0,0.0] 
				if classof processObject.baseobject == Editable_Poly then (
					vertexPolygons = polyOp.getFacesUsingVert processObject vertexIndex
					for i in vertexPolygons do (
						normal+=in coordsys world polyOp.getFaceNormal processObject i
					)
				) else (
					normal= getNormal processObject vertexIndex
				)
				normal=normalize normal 
				normal 
			)
			
			
			-- store an array to querry instead of the object
			fn storeOriginalMeshVertPositions = (
				originalMeshVertPositions= #()
				if classof originalMesh.baseobject == Editable_Poly then ( 
					for i=1 to numberofVerts do (append originalMeshVertPositions (in coordsys world polyop.getVert originalMesh i))
				) else (
						for i=1 to numberofVerts do (append originalMeshVertPositions (in coordsys world getVert originalMesh i))
				)
				originalMeshVertPositions
			)
			

	
			-- arrange the uvs
			function packVertUVs myMesh =(
				progressStart "打包UV" 
				convertTo myMesh Editable_Poly
				for i=1 to (numberofVerts) do (
					offset=1.0/(numberofVerts*2) -- find have a sample ratio
					currentPosition=(((i as float)-.5)/numberofVerts)
					polyop.setVertColor myMesh targetMorphUV i [currentPosition*255.0,128.0,0] ----*255.0
					append vertexUVPosition CurrentPosition
					--Progress Bar--
					updateProgAmount i numberofVerts
				)
				fixUVNames myMesh
				progressEnd()
			)
		fn normalToScalar Normal b3DigitsPrecision:false = (
				normal=normalize normal 
				if b3DigitsPrecision == true then (
					zSign=if Normal[3] > 0.0 then 1.0 else -1.0 
					Normal=clampVector Normal -.999 .999
					
					Normal=(Normal+1.0)*0.5	
					Normal=[ceil (Normal[1]*1000.0),ceil (Normal[2]*1000.0),0]
					normalScalar=zSign*((Normal[1])+(Normal[2]*.001)) as float
				) 
				else(
					Normal=(Normal+1.0)*0.5	
					Normal=[ceil (Normal[1]*100.0),ceil (Normal[2]*100.0),ceil (Normal[3]*100.0) ]
					normal=clampVector normal 0 99
					normalScalar=((Normal[1]*10.0)+(Normal[2]*.1)+(Normal[3]*.001)) as float
				)
				normalScalar as float
			)
				
			fn getVertPos model index= (
				pos=[0,0,0]
				if classof model.baseobject == editable_poly then (
					pos=in coordsys world polyop.getVert model index
				) else (
					pos=in coordsys world getVert model index
				)
				pos
			)
				
			fn populateMorphTargetArrays =(
				progressStart "Creating the Morph Targets" 
				masterCount=masterMorphArray.count
				for i=1 to masterCount do (
					global CurrentMorphTargetNormalArray=#()
					currentMorphTarget=masterMorphArray[i]
					global currentMorphVertexOffsetArray=#()
					MorphTargetProgressPercentage=updateProgAmount i masterCount
					for j=1 to numberofVerts do (
						oldnormal=((((normalize (getTheVertexNormal currentMorphTarget j))*[1.0,-1.0,1.0])+1.0)*0.5)*255.0   --法线顶点色数据
						append CurrentMorphTargetNormalArray oldnormal
						originalVertPos=originalMeshVertPositions[j]
						currentModelVertPos=getVertPos currentMorphTarget j
						if (captureAbsolutePositions.checked) 
						then (
							currentOffset=currentModelVertPos
						)
						else (
							currentOffset=(currentModelVertPos-originalVertPos)
						)
						currentOffset=[currentOffset[1],-1.0*currentOffset[2],currentOffset[3]]
						currentOffset*=255.0
						append currentMorphVertexOffsetArray currentOffset
					)
					append MorphVertOffsetArray currentMorphVertexOffsetArray
					append MorphNormalArray CurrentMorphTargetNormalArray
				)
			)
				
			fn updateAndClampSpinners = (
				spinnerAnimationRangeStart.value=clamp spinnerAnimationRangeStart.value -1000000000 spinnerAnimationRangeEnd.value
				spinnerAnimationRangeEnd.value=clamp spinnerAnimationRangeEnd.value spinnerAnimationRangeStart.value 1000000000
			)
			on 	spinnerAnimationRangeStart changed val do (		
				updateAndClampSpinners ()
			)
			on 	spinnerAnimationRangeEnd changed val do (
				updateAndClampSpinners ()
			)				
 
			
			fn makeSnapshotsReturnArray modelToSnap= (
					progressStart "正在烘培..." 
					FrameArray=#()
					NumberOfFrames = floor (spinnerAnimationRangeEnd.value-spinnerAnimationRangeStart.value) --/(spinnerAnimationRate.value+1)
					for i=0 to NumberOfFrames by (spinnerAnimationRate.value+1) do (
						newtime = spinnerAnimationRangeStart.value+i 
						newCopy=at time newtime snapshot modelToSnap
						meshop.unifyNormals newCopy #{1..newCopy.numfaces}
						--!convertto newCopy editable_poly
						append FrameArray newCopy
						updateProgAmount i NumberOfFrames
					)
					progressEnd()
				FrameArray
			)		
		
			fn attachMeshes mesh1 mesh2= (
				if classof mesh1 == editable_poly then mesh1.attach mesh2 mesh1
					else attach mesh1 mesh2 
			)
				
			fn makeAndMergeSnapShots arrayOfModels = (
				if arrayOfModels.count > 0 do (
					for i in arrayOfModels do (
						if checkmodel i do append masterMorphArray (makeSnapshotsReturnArray i) -- produces side by side arrays of models with the same frame count
					)
					-- consolidate multiple objects into one object so that the morph texture can be shared
					masterMorphArray1Count=masterMorphArray[1].count
					If masterMorphArray.count > 1 do (
						for i=2 to masterMorphArray.count do (
							--master arrays each item is a group
							for framecount=1 to masterMorphArray1Count do ( 
								-- Loop through each of the objects stored from each frame... then combine them with their associated paired meshes. the first mesh being the father of the others
								currentMasterObject=masterMorphArray[1][framecount]
								attachMeshes currentMasterObject masterMorphArray[i][framecount]
							)
						)
					)
					masterMorphArray = masterMorphArray[1] -- make master morph array a single dimensional array with the combined meshes
				)
			)
			
			
			fn renderOutTheTextures = (	
				  
				fopenexr.SetCompression CompressionType
				print("输出压缩格式:"+(CompressionType as string))
				fopenexr.setLayerOutputType 0 OutputType -- set layer 0  main layer to RGBA, RGB = 1
				print("输出通道:"+(OutputType as string))
				fopenexr.setLayerOutputFormat 0 OutputFormat --0 32 sets main layer to float 16 via 1. other options are 0 float 32, 2 int 32 
				global TextureName = getSaveFileName types:"EXR (*.EXR)|*.EXR"
				if TextureName == undefined then (
					messagebox "需要选择一个路径"
				)
				else(
					uvString="_UV"+((targetMorphUV-1) as string)
					TextureNameNormal= replace TextureName (findString TextureName ".EXR") 4 (uvString+"_Normals.BMP")
					TextureNameOffset= replace TextureName (findString TextureName ".EXR") 4 (uvString+".EXR")
					global FinalTexture = bitmap numberofVerts (MorphVertOffsetArray.count) filename:TextureNameOffset hdr:true;
					global FinalMorphTexture = bitmap numberofVerts (MorphVertOffsetArray.count) filename:TextureNameNormal hdr:true  gamma:1.0 ;--TextureName ;linear:true gamma:#default
					for i=0 to (MorphVertOffsetArray.count-1) do (
						setPixels FinalTexture [0, i] MorphVertOffsetArray[(i+1)]
						setPixels FinalMorphTexture [0, i] MorphNormalArray[(i+1)]  --设置图片对应坐标的像素颜色  2d坐标X分量是列，Y分量是行
						--setPixels FinalTexture [0, 1] MorphVertOffsetArray[(i+1)]
						--setPixels FinalMorphTexture [0, 1]  MorphNormalArray[(i+1)]  --设置图片对应坐标的像素颜色  2d坐标X分量是列，Y分量是行
					)
					save FinalTexture gamma:1.0
					close FinalTexture
					
					save FinalMorphTexture gamma:1.0
					close FinalMorphTexture
				)
			)
		
			fn removeMeshes = (
				if isvalidnode masterMorphArray[1] and masterMorphArray.count >0 do (
					delete masterMorphArray
					masterMorphArray=#()
				)
			)
			
			
			
		/*********************************************************************
		UI functions
		*********************************************************************/

			fn reinitVars = (
				masterMorphArray=#()
				MorphVertOffsetArray=#()
				originalMesh=undefined
				numberofVerts=0
				internalArrayOfStaticBaseMeshes=#()
				MorphTargetProgressPercentage=0.0
				originalMeshVertPositions=#()
				MorphNormalArray=#()
				tempMorphArray=#()
				
				
			)
			
			fn enableAnimatedControls enabled= (
				BakeBtn.enabled=enabled	
				spinnerAnimationRangeStart.enabled=enabled	
				spinnerAnimationRangeEnd.enabled=enabled	
				spinnerAnimationRate.enabled=enabled	
				BakeBtn.enabled=enabled
				--selectCurrentSelectedMeshes.enabled=not enabled
				reinitVars()
			)
			
			fn smoothcopy myMesh = (
				/********** Duplicate the Mesh **********/
				originalName=myMesh.name
				originalMesh=at time 0 snapshot myMesh
				originalMesh.name=originalName+"_MorphUV"+(targetMorphUV as string)+"_MorphExport"
				s=smooth()
				s.smoothingBits = 1
				addmodifier originalMesh s
				/********** Duplicate the Mesh **********/
				getvertCount originalMesh
				storeOriginalMeshVertPositions () 
			)
			fn updateSelectionButtons state = (
				if state==1 then (
					enableAnimatedControls true	
				)
				else (
					enableAnimatedControls false
				)
			)
			--on selectionOptions changed state do updateSelectionButtons state

			on help pressed do 
				(
					mes=#()
					HelpS=""
					append mes "1.输入动画开始和结束帧数"
					append mes "2.输入步长间隔"
					append mes "3.输入采样UV，默认使用第二套"
					append mes "4.选择是否需要绝对位置"
					append mes "5.点击按钮：【开始烘培】"
					for i in mes do HelpS+=i+"。\n"
					messageBox HelpS

				 )
			
			
			
			on BakeBtn pressed do (
				if checkUnitsSetup()==true do (
					SuspendEditing()
					try
					with redraw off (
						reinitVars()
						for i in selection do if checkmodel i do append internalArrayOfStaticBaseMeshes i
						geoConversionModelFailNamelist=#()
						for i in internalArrayOfStaticBaseMeshes do (
							modelCopy=convertto (snapshot i) editable_poly
							if ((getnumverts i)!= (getnumverts modelCopy)) do append geoConversionModelFailNamelist i.name
							delete modelCopy
						)
						if geoConversionModelFailNamelist.count > 0 then  
							(
								finalWarningString="模型必须转换为可以编辑多边形. \r\r "
								for i in geoConversionModelFailNamelist do append finalWarningString  ("\r - "+i)
								messagebox finalWarningString
							)  
						else(
							if internalArrayOfStaticBaseMeshes.count > 0 then (
								makeAndMergeSnapShots internalArrayOfStaticBaseMeshes -- populates masterMorphArray
								smoothcopy masterMorphArray[1] -- smooth mesh becomes  originalMesh storeOriginalMeshVertPositions -- Also sets vert count
								packVertUVs originalMesh 
								populateMorphTargetArrays () --		MorphVertOffsetArray MorphNormalArray
								removeMeshes()
								
								renderOutTheTextures () -- requires MorphVertOffsetArray.count to be correct
								fixUVNames originalMesh 
								convertto originalMesh editable_mesh
								select originalMesh
								--addmodifier originalMesh (Materialmodifier ()) --ui:on
							)	else (
								messagebox "没有选择模型."
							)
						)
						
					)
					catch (
						msgBreak ()
						ResumeEditing()
					)
				)
				ResumeEditing()
			)
			
			
			


	)-- end rollout
	

	
	CreateDialog TexMorphRollout Morph_Floater height:500 width:300 style:#(#style_resizing,#style_minimizebox,#style_toolwindow,#style_titlebar,#style_border,#style_sysmenu,#style_sunkenedge)--)
	
	
	

	-- global Morph_Floater = newRolloutFloater "" 175 400 
	
	
	-- addRollout TexMorphRollout Morph_Floater






)