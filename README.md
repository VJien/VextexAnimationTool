
> 本文介绍从max到UE4顶点动画实现流程
>
> 使用的方式是贴图记录顶点位置和法线信息通过材质球使静态模型模拟动画的播放



![Alt text](https://img.supervj.top/imgd1.gif)

[脚本下载](https://github.com/VJien/VextexAnimationTool.git)

### 顶点缓存脚本

- **如果是非骨骼动画，可以直接跳过此步骤**

用顶点缓存脚本把骨骼动画信息保存到==pointCache修改器==内，脚本界面如下

![Alt text](https://img.supervj.top/imgd2.jpg)

- 缓存文件可以选择自定义路径
- 烘培范围默认是时间轴的时间，一般不需要自定义

完成后如下图所示

![Alt text](https://img.supervj.top/imgvertexAnim_pointCache.jpg)

skin修改器会被自动禁用，然后就可以进入下一步骤



### 用顶点动画导出工具

脚本界面如下 

![Alt text](https://img.supervj.top/imgd4.jpg)

- 动画设置的的开始和结束一般不用修改，**间隔**参数后有详细数据测试
- 压缩格式和渲染通道不建议修改
- 输出格式可以用FLOAT16减少体积，测试影响不大



点击【开始烘培】后选择目录保存2张贴图，然后模型窗口自动生成后缀为**MorpohExport**的模型，选择导出【**非动画模型**】，得到如下图

![Alt text](https://img.supervj.top/imgd5.jpg)

##### 注意

1. 每个动作都需要一个FBX和2个贴图



##### 测试间隔参数

**模型顶点数为：1729**

1. 以Run动作为测试，模型资源大小：189kb
   1. 原始数据：25帧，2张贴图大小合计（非cook数据，以下简称贴图)：273kb
   2. 间隔1帧：13帧，贴图：143kb
   3. 间隔2帧：9帧数，贴图：99kb
   4. 间隔3帧：7帧，贴图：76kb
   5. 间隔4帧：5帧，贴图：60kb
   6. 间隔5帧：5帧，贴图：53kb
2. 以attack动作测试，模型资源大小：189kb
   1. 原始数据：91帧，贴图：962kb
   2. 间隔1帧：46帧，贴图：501kb
   3. 间隔2帧：31帧数，贴图：343kb
   4. 间隔3帧：23帧，贴图：262kb
   5. 间隔4帧：19帧，贴图：214kb
   6. 间隔5帧：16帧，贴图：180kb

##### 结论

1. 原始动画的帧数直接决定贴图**y**轴尺寸（像素数量），意味着帧数越少贴图越小（线性）
2. 原始动画的顶点数决定贴图**x**轴，所以尽可能的降低顶点数，同样意味着顶点数越少贴图越小
3. 由于顶点材质球（具体见下面材质球部分）计算有过度效果，所以去掉中间帧数（设置间隔参数）带来的影响并不大，损失部分细节，但不会出现跳跃现象，但是资源大小是线性变化的
4. 从max中对动画进行帧数手动减半，效果等同于用脚本设置间隔参数1，而且效果更直接，方便观察和调整



### UE4部分

##### 导入模型

![](https://img.supervj.top/imgvertexAnim_ImportMesh.jpg)

- 如图所示选项需要设置

##### EXR贴图

![](https://img.supervj.top/imgvertexAnim_EXR.jpg)

- 参数设置如图
  - sRGB需要去掉
  - 压缩格式设置成HDR



##### Normal贴图

![](https://img.supervj.top/imgvertexAnim_nor.jpg)

- 参数设置
  - sRGB去掉
  - 压缩格式设置为VectorDisplacementMap
  - 其他不是很关键

##### 材质球

![](https://img.supervj.top/imgvertexAnim_mat.jpg)

- 使用UE自带的材质函数
  - 设置材质球的TangentSpaceNormal选项为false
  - NumCustomizedUVs设置为4
  - 图中sp节点为动画速度
  - Mor参数为动画帧数
    - 测试发现参数不能小于帧数，也就是贴图的Y轴像素大小
    - 当帧数过小，比如5帧的时候，设置这个Mor参数为5的较大整数倍，比如100，可以去掉原本有的跳帧显现



### 脚本核心功能解释

##### 顶点缓存脚本

- max自带顶点缓存插件，本脚本工作原理是调用了插件的功能
- 核心代码如下

```lua

createDialog test_dialog
	
	)

	--Label RangeSelect "选择导出范围"
	checkbox cbCustomRange "自定义范围" checked:false tooltip:"默认使用时间轴范围"
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
			 for i = 1 to selection.count do    --遍历所有选择的物体，一般只会选择1个
			(
				A= selection as array
				OBJname = A[i].name + ".xml"
				FilePathName= PCpath.text
				PointCacheName= FilePathName +@"\"+ OBJname
				addmodifier A[i] (Point_Cache ())   --添加点缓存修改器
				A[i].modifiers[#Point_Cache].filename=PointCacheName  
				if cbCustomRange.checked then  --如果开启了自定义，就设置插件内如下参数
				(
					A[i].modifiers[#Point_Cache].playbackType=2
					A[i].modifiers[#Point_Cache].playbackStart=Start.value
					A[i].modifiers[#Point_Cache].playbackEnd=End.value
				)
				else
				(
					A[i].modifiers[#Point_Cache].playbackType=0
				)
				
				cacheOps.recordcache A[i].modifiers[#point_cache] --记录点信息
				cacheOps.DisableBelow A[i].modifiers[#point_cache] --关闭下面的修改器，一般就是skin

			Bake_prog.value = 100.*i/A.count
			

			)
			
					Messagebox "生成完毕"
					
				
		)
	)


			
)
createdialog PointCacheTool


```



##### 顶点动画导出工具

- 修改自Epic的顶点动画脚本，原版插件多数功能无用而且无导出选项
- 核心代码如下

```lua
fn renderOutTheTextures = (	
				  
				fopenexr.SetCompression CompressionType  --压缩格式，一般不压缩
				print("输出压缩格式:"+(CompressionType as string))
				fopenexr.setLayerOutputType 0 OutputType -- 输出通道，一般就是RPG
				print("输出通道:"+(OutputType as string))
				fopenexr.setLayerOutputFormat 0 OutputFormat --输出格式，一般FLOAT16够用
				global TextureName = getSaveFileName types:"EXR (*.EXR)|*.EXR"
				if TextureName == undefined then (
					messagebox "需要选择一个路径"
				)
				else(
					uvString="_UV"+((targetMorphUV-1) as string)
					TextureNameNormal= replace TextureName (findString TextureName ".EXR") 4 (uvString+"_Normals.BMP")
					TextureNameOffset= replace TextureName (findString TextureName ".EXR") 4 (uvString+".EXR")
					global FinalTexture = bitmap numberofVerts (MorphVertOffsetArray.count) filename:TextureNameOffset hdr:true;
					global FinalMorphTexture = bitmap numberofVerts (MorphVertOffsetArray.count) filename:TextureNameNormal hdr:true  gamma:1.0 ;
					for i=0 to (MorphVertOffsetArray.count-1) do (
						setPixels FinalTexture [0, i] MorphVertOffsetArray[(i+1)]
						setPixels FinalMorphTexture [0, i] MorphNormalArray[(i+1)]   --设置图片对应坐标的像素颜色  2d坐标X分量是列，Y分量是行
--设置图片对应坐标的像素颜色  2d坐标X分量是列，Y分量是行
					)
					save FinalTexture gamma:1.0
					close FinalTexture
					
					save FinalMorphTexture gamma:1.0
					close FinalMorphTexture
				)
			)
```