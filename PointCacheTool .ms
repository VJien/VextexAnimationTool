try destroyDialog ::PointCacheTool catch()
rollout PointCacheTool "顶点缓存工具 " 
(
	Label title "____________by VJ____________"
	--global bDisBelow=true
group "设置" 
(
	
	edittext PCPath "路径" text:"D:/"	
	button _SaveFolder "选择缓存保存路径" width:130
	on _SaveFolder pressed do 
	(
	
		FolderPath=getSavePath caption:"选择缓存文件夹" initialDir:maxfilepath
		if folderpath != undefined do
		PCpath.text= folderPath
		
	)
	Button _SelectPerModifier "选择变形器" width:130
	
	on _SelectPerModifier pressed do 
	(
		
		try destroyDialog ::test_dialog catch()
	
rollout test_dialog "模式" width:300 height:320
(
	
local modifierClasses = #()
local objectSets = #()

fn collectmodifierClasses =
(
for obj in objects do 
(
for objMod in obj.modifiers do
(
local modIndex = findItem modifierClasses (classOf objMod as string)
if modIndex == 0 then
(
append modifierClasses (classOf objMod as string)
append objectSets #(obj)
)
else append objectSets[modIndex] obj -- otherwise append it to the corresponding object set
)
)
)

fn selectObjectsByMod modStr =
select objectSets[findItem modifierClasses modStr]

listbox modifiersToSelect "选择"

on test_dialog open do
(
collectmodifierClasses()
modifiersToSelect.items = sort (for item in modifierClasses collect item as string)
)

on modifiersToSelect doubleClicked item do
(
selectObjectsByMod modifiersToSelect.items[item]
	DestroyDialog (test_dialog)
)

)


createDialog test_dialog
		
		
	)

	
	
	
	--Label RangeSelect "选择导出范围"
	checkbox cbCustomRange "自定义范围" checked:false tooltip:"默认使用时间轴范围"
	
	--dropdownlist PBType  Items:#("原始范围","自定义开始","自定义范围")
	spinner Start "开始帧:" range:[-10000,10000,0] type:#integer enabled:false
	Spinner End "结束帧:" range:[-10000,10000,100] type:#integer enabled:false



	on cbCustomRange changed stat do
	(
		if cbCustomRange.checked==true then 
		(
			Start.enabled=true 
			End.enabled=true
		)
		else
		(
			Start.enabled=false 
			End.enabled=false
		)
	)


	)

	Button _BakePC "开始缓存" width:130 height:64
	progressbar Bake_prog color:green 
	on _BakePC pressed do 
	(
		if PCpath.text=="" then 
			messagebox "请选择输出文件夹以保存顶点缓存文件"
		else 		
		if $==undefined then
		messagebox"选择烘培物体"
		else
		(
			 for i = 1 to selection.count do
			(
				A= selection as array
				OBJname = A[i].name + ".xml"
				FilePathName= PCpath.text
				PointCacheName= FilePathName +@"\"+ OBJname
				addmodifier A[i] (Point_Cache ())
				A[i].modifiers[#Point_Cache].filename=PointCacheName
				if cbCustomRange.checked then
				(
					A[i].modifiers[#Point_Cache].playbackType=2
					A[i].modifiers[#Point_Cache].playbackStart=Start.value
					A[i].modifiers[#Point_Cache].playbackEnd=End.value
				)
				else
				(
					A[i].modifiers[#Point_Cache].playbackType=0
				)
				
				cacheOps.recordcache A[i].modifiers[#point_cache] 
				cacheOps.DisableBelow A[i].modifiers[#point_cache] 

			Bake_prog.value = 100.*i/A.count
			

			)
			
					Messagebox "生成完毕"
					
				
		)
	)




			
)
createdialog PointCacheTool
————————————————
