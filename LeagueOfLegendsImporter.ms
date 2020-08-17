/* League of Legends Model Importer by Gistix, 
based off of nightFlarer's Max, finale00's Noesis and Zac Berkowitz's Blender importers
For version 0 files only*/

clearlistener()
(
	fn ReadFixedString bstream fixedLen =
	(
	   local str = ""
	   for i = 1 to fixedLen do
	   (
		  str0 = ReadByte bstream #unsigned
		 str+= bit.intAsChar str0
	   )
	   str
	)

	fn ReadNullString f = (
		local str = ""
		
		for i = 1 to 32 do (
			byte = ReadByte f #unsigned
			
			if (byte == 0 and str != "") then
				exit
			
			str += bit.intAsChar (byte)
		)
		
		str
	)

	struct LeagueMat (
		name,
		startVert,
		numVer,
		startIndex,
		numIndex
	)

	struct LeagueVert (
		position,
		boneid,
		weight,
		normal,
		uv
	)

	struct LeagueMesh (
		faces,
		vertice,
		materials	
	)

	fn ReadMesh f = (
		leagueMesh = LeagueMesh faces:#()  vertice:#() materials:#()

		unknown = readlong f #unsigned
		unknown2 = readshort f #unsigned
		unknown3 = readshort f #unsigned
		materialCount = readlong f #unsigned

		for i = 1 to materialCount do (
			materialName = ReadFixedString f 64
			
			startVertex = readlong f #unsigned
			numVertices = readlong f #unsigned
			
			startIndex = readlong f #unsigned
			numIndices = readlong f #unsigned
			
			append leagueMesh.materials (LeagueMat name:materialName startVert:startVertex numVer:numVertices startIndex:startIndex numIndex:numIndices)
		)

		unknown4 = readlong f #unsigned
		indicesCount = readlong f #unsigned
		vertCount = readlong f #unsigned

		fseek f 48 #seek_cur

		for i = 1 to indicesCount/3 do(
			fa = readshort f #unsigned + 1
			fb = readshort f #unsigned + 1
			fc = readshort f #unsigned + 1
			append leagueMesh.faces [fa, fb, fc]
		)

		position = #()
		boneid = #()
		weight = #()
		normal = #()
		uv = #()
		
		for x = 1 to vertCount do(
			vx=readfloat f
			vy=readfloat f
			vz=readfloat f

			b1 = readbyte f #unsigned + 1
			b2 = readbyte f #unsigned + 1
			b3 = readbyte f #unsigned + 1
			b4 = readbyte f #unsigned + 1
			
			w1=readfloat f
			w2=readfloat f
			w3=readfloat f
			w4=readfloat f
			
			nx=readfloat f
			ny=readfloat f
			nz=readfloat f
			
			u=readfloat f
			v=readfloat f			
			
			append position [vx, vy, vz] 
			append boneid #(b1, b2, b3, b4)
			append weight #(w1, w2, w3, w4)
			append normal [nx, ny, nz]	
			append uv [u, 1-v, 0]
		)
		
		leagueMesh.vertice = LeagueVert position:position boneid:boneid weight:weight normal:normal	uv:uv

		return leagueMesh
	)

	fn CreateMaterial leagueMesh = (
		mm = multimaterial numsubs:leagueMesh.materials.count
		
		materialIDs = #()
		
		for i = 1 to leagueMesh.materials.count do (
			leagueMat = leagueMesh.materials[i]
			mm.materialList[i].name = leagueMat.name
			
			for j=1 to leagueMat.numIndex/3 do (
				append materialIDs i
			)
		)
		
		return #(mm, materialIDs)
	)

	fn CreateMesh leagueMesh leagueSkeletonData = (
		leagueSkeleton = leagueSkeletonData[1]
		leagueAnimSkeleton = leagueSkeletonData[2]
		
		materialData = CreateMaterial leagueMesh
		
		msh = mesh vertices:leagueMesh.vertice.position tverts:leagueMesh.vertice.uv faces:leagueMesh.faces materialIDs:materialData[2]
		msh.material = materialData[1]
		
		buildTVFaces msh
		for j = 1 to leagueMesh.faces.count do setTVFace msh j leagueMesh.faces[j]
		rotate msh (eulerAngles 90 0 0)
		
		skinMod = skin ()
		addModifier msh skinMod
		
		max modify mode
		modPanel.setCurrentObject skinMod
		
		for i = 1 to leagueAnimSkeleton.count do (
			leagueBone = leagueSkeleton[leagueAnimSkeleton[i]]
			
			if (i != leagueAnimSkeleton.count) then
				skinOps.addBone skinMod leagueBone.node 0
			else
				skinOps.addBone skinMod leagueBone.node -1
		)
		
		completeRedraw ()
		
		for i = 1 to leagueMesh.vertice.weight.count do (
			skinOps.ReplaceVertexWeights skinMod i leagueMesh.vertice.boneid[i] leagueMesh.vertice.weight[i]
		)
	)

	struct LeagueBone (
		id,
		parent,
		name,
		position,
		scale,
		rotation,
		ct,
		extra,
		node
	)
	
	fn ReadBone f = (
		unknown = readshort f #unsigned		
		id = readshort f #unsigned
		parent = readlong f #unsigned		
		name = readlong f #unsigned
		twopointone = readfloat f
		
		position = [readfloat f, readfloat f, readfloat f]
		
		scale = [readfloat f, readfloat f, readfloat f]
		rotation = quat (readfloat f) (readfloat f) (readfloat f) (readfloat f)
		ct = [readfloat f, readfloat f, readfloat f]
		extra =  #(readfloat f, readfloat f, readfloat f, readfloat f, readfloat f, readfloat f, readfloat f, readfloat f)
		
		return (LeagueBone id:id parent:parent name:name position:position scale:scale rotation:rotation ct:ct extra:extra)	
	)
	
	fn ReadSkeleton f = (
		fileLength = readlong f #unsigned
		unknown = readlong f #unsigned
		version = readlong f #unsigned
		zero = readshort f #unsigned	
		boneCount = readshort f #unsigned		
		boneIDCount = readlong f #unsigned		
		offsetVertexData = readlong f #unsigned

		offset1= readlong f #unsigned
		offsetToAnimID = readlong f #unsigned
		offset2 = readlong f #unsigned
		offsetToStrings = readlong f #unsigned	
		offset3 = readlong f #unsigned	
		
		fseek f offsetVertexData #seek_set
		
		bones = #()

		for i=1 to boneCount do (
			append bones (ReadBone f)
		)

		fseek f (offsetToAnimID) #seek_set
		
		reorderedBones = #()
		
		for i=1 to boneIDCount do (
			animID = (readshort f #unsigned) + 1
			
			append reorderedBones bones[animID].id
		)	
		
		fseek f (offsetToStrings+4) #seek_set

		for i=1 to boneCount do (
			bones[i].name = ReadNullString f
		)	

		return #(bones, reorderedBones)
	)

	fn CreateSkeleton leagueSkeletonData = (
		leagueSkeleton = leagueSkeletonData[1]
		
		for i=1 to leagueSkeleton.count do (
			leagueBone = leagueSkeleton[i]
			
			bone = bonesys.createbone leagueBone.position leagueBone.position [0, 0, 1]
		
			bone.name = leagueBone.name

			bone.width = 0.01
			bone.height = 0.01

			bone.wirecolor = yellow
			bone.showlinks = true
			
			If (leagueBone.parent != 65535) do ( 
				bone.parent = leagueSkeleton[leagueBone.parent + 1].node
				in coordsys parent bone.pos = leagueBone.position
			)
			
			bone.setBoneEnable false 0
			bone.pos.controller = TCB_position ()
			bone.rotation.controller = TCB_rotation ()

			leagueBone.node = bone
		)

		for i=1 to leagueSkeleton.count do (
			leagueBone = leagueSkeleton[i]

			in coordsys local rotate leagueBone.node leagueBone.rotation
				
			If (leagueBone.parent == 65535) then 
				in coordsys world about [0, 0, 0] rotate leagueBone.node (eulerAngles 90 0 0)			
		)		
	)
	
	fn ImportLeagueSkin = ( 
		fname = getOpenFileName \ 
		caption:"League of Legends Skin Model File" \
		types:"League of Legends Skin Model File(*.skn)|*.skn" \
		historyCategory:"LeagueofLegendsObjectPresets"
		f = fopen fname "rb"
		leagueMesh = ReadMesh f
		fclose f

		fnameSkl = (getFilenamePath  fname) + (getFilenameFile  fname) + ".skl"
		f = fopen fnameSkl "rb"
		leagueSkeletonData = ReadSkeleton f
		fclose f

		CreateSkeleton leagueSkeletonData
		CreateMesh leagueMesh leagueSkeletonData
	)
	
	ImportLeagueSkin ()
)

gc()
