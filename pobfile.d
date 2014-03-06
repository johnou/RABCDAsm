/*
 *  Copyright 2013 Tony Tyson <teesquared@twistedwords.net>
 *  Copyright 2010, 2011 Vladimir Panteleev <vladimir@thecybershadow.net>
 *  This file is part of RABCDAsm.
 *
 *  RABCDAsm is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  RABCDAsm is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with RABCDAsm.  If not, see <http://www.gnu.org/licenses/>.
 */

module pobfile;

import std.c.string;
import std.conv;
import std.exception;
import std.stdio;
import std.string : format;

import swffile;
import tagoptions;
import tagreader;
import tagtypes;
import tagwriter;

final class PobFile
{
	// v1
	ushort characterId;
	ushort depth;
	Matrix matrix;
	ColorTransform colorTransform;

	// v2
	bool hasClipActions;
	bool hasClipDepth;
	bool hasName;
	bool hasRatio;
	bool hasColorTransform;
	bool hasMatrix;
	bool hasCharacterId;
	bool hasMove;

	ushort ratio;
	string name;
	ushort clipDepth;
	ClipActions clipActions;

	// v3
	bool hasImage;
	bool hasClassName;
	bool hasCacheAsBitmap;
	bool hasBlendMode;
	bool hasFilterList;

	string className;
	Filter[] surfaceFilterList;
	ubyte blendMode;
	ubyte bitmapCache;

	TagType type;
	ubyte swfVersion;
	bool forceOneBitZeroTranslate;

	bool isType1()
	{
		return type == TagType.PlaceObject;
	}

	bool isType2()
	{
		return type == TagType.PlaceObject2;
	}

	bool isType3()
	{
		return type == TagType.PlaceObject3;
	}

	static bool isTagType(ref SWFFile.Tag tag)
	{
		return tag.type == TagType.PlaceObject || tag.type == TagType.PlaceObject2 || tag.type == TagType.PlaceObject3;
	}

	static ubyte[] getTagData(ref SWFFile.Tag tag)
	{
		return tag.data;
	}

	static PobFile read(TagType t, ubyte[] data, TagOptions tagOptions)
	{
		return (new PobReader(t, data, tagOptions)).pob;
	}

	ubyte[] write()
	{
		return (new PobWriter(this)).buf;
	}

	override string toString()
	{
		string r = "";

		r ~= format("%s depth (%d) ", tagNames[type], depth);

		if (hasClipActions) r ~= "hasClipActions ";
		if (hasClipDepth) r ~= format("hasClipDepth (%d) ", clipDepth);
		if (hasName) r ~= format("hasName (%s) ", name);
		if (hasRatio) r ~= format("hasRatio (%d) ", ratio);
		if (hasMatrix) r ~= format("hasMatrix (%s) ", matrix.toString());
		if (hasColorTransform) r ~= format("hasColorTransform (%s) ", colorTransform.toString());
		if (hasCharacterId) r ~= format("hasCharacterId (%d) ", characterId);
		if (hasMove) r ~= "hasMove ";
		if (hasImage) r ~= "hasImage ";
		if (hasClassName) r ~= format("hasClassName (%s) ", className);
		if (hasCacheAsBitmap) r ~= format("hasCacheAsBitmap (%d) ", bitmapCache);
		if (hasBlendMode) r ~= format("hasBlendMode (%d) ", blendMode);
		if (hasFilterList) r ~= format("hasFilterList (%d) ", surfaceFilterList.length);

		return r;
	}
}

private final class PobReader : TagReader
{
	PobFile pob;

	this(TagType t, ubyte[] buf, TagOptions tagOptions)
	{
		try
		{
			super(buf);
			pob = new PobFile();

			pob.type = t;
			pob.swfVersion = tagOptions.swfVersion;

			if (!pob.isType1())
			{
				pob.hasClipActions = readBit();
				pob.hasClipDepth = readBit();
				pob.hasName = readBit();
				pob.hasRatio = readBit();
				pob.hasColorTransform = readBit();
				pob.hasMatrix = readBit();
				pob.hasCharacterId = readBit();
				pob.hasMove = readBit();

				if (!pob.isType2())
				{
					enforce(readBit() == false, "Invalid bit value!");
					enforce(readBit() == false, "Invalid bit value!");
					enforce(readBit() == false, "Invalid bit value!");
					pob.hasImage = readBit();
					pob.hasClassName = readBit();
					pob.hasCacheAsBitmap = readBit();
					pob.hasBlendMode = readBit();
					pob.hasFilterList = readBit();
				}
			}
			else
			{
				pob.hasColorTransform = true;
				pob.hasMatrix = true;
			}

			if (pob.isType1())
			{
				pob.characterId = readU16();
				pob.depth = readU16();
			}
			else
			{
				pob.depth = readU16();
				if (pob.hasClassName)
					pob.className = readStringZ();
				if (pob.hasCharacterId)
					pob.characterId = readU16();
			}

			if (pob.hasMatrix)
				readMatrix(pob.matrix);

			if (pob.hasColorTransform && pos < buf.length)
				readColorTransform(pob.colorTransform);
			else
				pob.hasColorTransform = false; // optional for type1

			if (pob.hasRatio)
				pob.ratio = readU16();

			if (pob.hasName)
				pob.name = readStringZ();

			if (pob.hasClipDepth)
				pob.clipDepth = readU16();

			if (pob.hasFilterList)
				readFilterList(pob.surfaceFilterList);

			if (pob.hasBlendMode)
				pob.blendMode = readU8();

			if (pob.hasCacheAsBitmap && !tagOptions.skipCacheAsBitmapByte)
				pob.bitmapCache = readU8();

			if (pob.hasClipActions)
				readClipActions(pob.clipActions);

			enforce(pos == buf.length, format("Invalid tag data %d %d", pos, buf.length));
		}
		catch (Exception e)
		{
			stderr.writeln(e.msg);
			stderr.writeln(pob);
			stderr.writeln("To fix this issue, try ", tagOptions.skipCacheAsBitmapByte ? "not " : "" ,"using the option skipCacheAsBitmapByte.");
			throw new Exception(format("%s(%d): Error at %d (0x%X):", e.file, e.line, pos, pos), e);
		}
	}

	void readMatrix(ref Matrix m)
	{
		syncBits();

		m.hasScale = readBit();
		if (m.hasScale)
		{
			uint nScaleBits = readUBits(5);
			m.scaleX = readSBits(nScaleBits);
			m.scaleY = readSBits(nScaleBits);
		}

		m.hasRotate = readBit();
		if (m.hasRotate)
		{
			uint nRotateBits = readUBits(5);
			m.rotateSkew0 = readSBits(nRotateBits);
			m.rotateSkew1 = readSBits(nRotateBits);
		}

		uint nTranslateBits = readUBits(5);
		m.translateX = readSBits(nTranslateBits);
		m.translateY = readSBits(nTranslateBits);

		pob.forceOneBitZeroTranslate = nTranslateBits == 1 && m.translateX == 0 && m.translateY == 0;
	}

	void readColorTransform(ref ColorTransform c)
	{
		syncBits();

		c.hasAlpha = !pob.isType1();

		c.hasAdd = readBit();
		c.hasMult = readBit();

		uint nbits = readUBits(4);

		if (c.hasMult)
		{
			c.redMultTerm = readSBits(nbits);
			c.greenMultTerm = readSBits(nbits);
			c.blueMultTerm = readSBits(nbits);

			if (c.hasAlpha)
				c.alphaMultTerm = readSBits(nbits);
			else
				c.alphaMultTerm = 0;
		}

		if (c.hasAdd)
		{
			c.redAddTerm = readSBits(nbits);
			c.greenAddTerm = readSBits(nbits);
			c.blueAddTerm = readSBits(nbits);

			if (c.hasAlpha)
				c.alphaAddTerm = readSBits(nbits);
			else
				c.alphaAddTerm = 0;
		}
	}

	void readFilterList(ref Filter[] filterList)
	{
		ubyte count = readU8();
		filterList = new Filter[count];

		for (uint n = 0; n < count; ++n)
		{
			Filter f;
			f.type = cast(FilterType)readU8();

			switch (f.type)
			{
			case FilterType.DropShadow:
				readDropShadowFilter(f.DropShadowFilter);
				break;
			case FilterType.Blur:
				readBlurFilter(f.BlurFilter);
				break;
			case FilterType.Glow:
				readGlowFilter(f.GlowFilter);
				break;
			case FilterType.Bevel:
				readBevelFilter(f.BevelFilter);
				break;
			case FilterType.GradientGlow:
				readGradientGlowFilter(f.GradientGlowFilter);
				break;
			case FilterType.Convolution:
				readConvolutionFilter(f.ConvolutionFilter);
				break;
			case FilterType.ColorMatrix:
				readColorMatrixFilter(f.ColorMatrixFilter);
				break;
			case FilterType.GradientBevel:
				readGradientBevelFilter(f.GradientBevelFilter);
				break;
			default:
				throw new Exception("Unknown filter type!");
				break;
			}

			filterList[n] = f;
		}
	}

	void readDropShadowFilter(ref Filter._DropShadowFilter f)
	{
		f.color = readRgba();
		f.blurX = readS32();
		f.blurY = readS32();
		f.angle = readS32();
		f.distance = readS32();
		f.strength = readU16();
		f.flags = readU8();
	}

	void readBlurFilter(ref Filter._BlurFilter f)
	{
		f.blurX = readS32();
		f.blurY = readS32();
		f.passes = readU8();
	}

	void readGlowFilter(ref Filter._GlowFilter f)
	{
		f.color = readRgba();
		f.blurX = readS32();
		f.blurY = readS32();
		f.strength = readU16();
		f.flags = readU8();
	}

	void readBevelFilter(ref Filter._BevelFilter f)
	{
		f.highlightColor = readRgba();
		f.shadowColor = readRgba();
		f.blurX = readS32();
		f.blurY = readS32();
		f.angle = readS32();
		f.distance = readS32();
		f.strength = readU16(); // fixed 8.8
		f.flags = readU8(); // several fields
	}

	void readGradientGlowFilter(ref Filter._GradientGlowFilter f)
	{
		f.numColors = readU8();
		f.gradientColors = new uint[f.numColors];
		for (uint i = 0; i < f.numColors; ++i)
			f.gradientColors[i] = readRgba();
		f.gradientRatio = new ubyte[f.numColors];
		for (uint i = 0; i < f.numColors; ++i)
			f.gradientRatio[i] = readU8();
		f.blurX = readS32();
		f.blurY = readS32();
		f.angle = readS32();
		f.distance = readS32();
		f.strength = readU16(); // fixed 8.8
		f.flags = readU8(); // several fields
	}

	void readConvolutionFilter(ref Filter._ConvolutionFilter f)
	{
		f.matrixX = readU8();
		f.matrixY = readU8();
		f.divisor = readFloat();
		f.bias = readFloat();
		const uint msize = f.matrixX * f.matrixY;
		f.matrix = new float[msize];
		for (int i = 0; i < msize; ++i)
			f.matrix[i] = readFloat();
		f.color = readRgba();
		f.flags = readU8(); // several fields
	}

	void readColorMatrixFilter(ref Filter._ColorMatrixFilter f)
	{
		for (int i = 0; i < 20; ++i)
			f.values[i] = readFloat();
	}

	void readGradientBevelFilter(ref Filter._GradientBevelFilter f)
	{
		f.numColors = readU8();
		f.gradientColors = new uint[f.numColors];
		for (uint i = 0; i < f.numColors; ++i)
			f.gradientColors[i] = readRgba();
		f.gradientRatio = new ubyte[f.numColors];
		for (uint i = 0; i < f.numColors; ++i)
			f.gradientRatio[i] = readU8();
		f.blurX = readS32();
		f.blurY = readS32();
		f.angle = readS32();
		f.distance = readS32();
		f.strength = readU16(); // fixed 8.8
		f.flags = readU8(); // several fields
	}

	uint readClipEventFlags()
	{
		uint flags;

		if (pob.swfVersion > 5)
			flags = readU32();
		else
			flags = readU16();

		return flags;
	}

	void readClipActions(ref ClipActions c)
	{
		enforce(readU16() == 0, "Invalid tag data!");
		c.allEventFlags = readClipEventFlags();

		uint n = 0;
		while (true)
		{
			ClipActionRecord r;
			if (!readClipActionRecord(r))
				break;
			c.clipActionRecords[n++] = r;
		}

		enforce(n > 0, "Invalid ClipActions!");
	}

    bool readClipActionRecord(ref ClipActionRecord r)
	{
		uint n = 0;
		uint flags = readClipEventFlags();
		if (flags != 0) // 0 is ClipActionEndFlag
		{
			r.eventFlags = flags;

			uint size = readU32();

			enforce(size > 0, "Invalid ClipActionRecord size!");

			if (flags & 0x00020000) // keyPress
			{
				--size;
				r.keyCode = readU8();
			}

			while (size > 0)
			{
				Action a;
				readAction(a);
				r.actions[n++] = a;
				uint length = a.getLength();
				enforce(length > size, "Invalid Action size!");
				size -= length;
			}

			return true;
		}

		return false;
	}

	void readAction(ref Action a)
	{
		a.actionCode = readU8();

		if (a.actionCode >= 0x80)
		{
			const uint length = readU16();
			enforce(length > 0, "Invalid Action length!");
			a.data = new ubyte[length];
			readExact(a.data, length);
		}
	}
}

private final class PobWriter : TagWriter
{
	PobFile pob;

	this(PobFile pob)
	{
		this.pob = pob;

		if (!pob.isType1())
		{
			writeBit(pob.hasClipActions);
			writeBit(pob.hasClipDepth);
			writeBit(pob.hasName);
			writeBit(pob.hasRatio);
			writeBit(pob.hasColorTransform);
			writeBit(pob.hasMatrix);
			writeBit(pob.hasCharacterId);
			writeBit(pob.hasMove);

			if (!pob.isType2())
			{
				writeBits(0, 3);
				writeBit(pob.hasImage);
				writeBit(pob.hasClassName);
				writeBit(pob.hasCacheAsBitmap);
				writeBit(pob.hasBlendMode);
				writeBit(pob.hasFilterList);
			}
		}

		if (pob.isType1())
		{
			writeU16(pob.characterId);
			writeU16(pob.depth);
		}
		else
		{
			writeU16(pob.depth);
			if (pob.hasClassName)
				writeStringZ(pob.className);
			if (pob.hasCharacterId)
				writeU16(pob.characterId);
		}

		if (pob.hasMatrix)
			writeMatrix(pob.matrix);

		if (pob.hasColorTransform)
			writeColorTransform(pob.colorTransform);

		if (pob.hasRatio)
			writeU16(pob.ratio);

		if (pob.hasName)
			writeStringZ(pob.name);

		if (pob.hasClipDepth)
			writeU16(pob.clipDepth);

		if (pob.hasFilterList)
			writeFilterList(pob.surfaceFilterList);

		if (pob.hasBlendMode)
			writeU8(pob.blendMode);

		if (pob.hasCacheAsBitmap)
			writeU8(pob.bitmapCache);

		if (pob.hasClipActions)
			writeClipActions(pob.clipActions);

		buf.length = pos;
	}

	void writeMatrix(ref Matrix m)
	{
		writeBit(m.hasScale);
		if (m.hasScale)
		{
			uint nScaleBits = m.getNumScaleBits();
			writeUBits(nScaleBits, 5);
			writeSBits(m.scaleX, nScaleBits);
			writeSBits(m.scaleY, nScaleBits);
		}

		writeBit(m.hasRotate);
		if (m.hasRotate)
		{
			uint nRotateBits = m.getNumRotateBits();
			writeUBits(nRotateBits, 5);
			writeSBits(m.rotateSkew0, nRotateBits);
			writeSBits(m.rotateSkew1, nRotateBits);
		}

		uint nTranslateBits = m.getNumTranslateBits();

		if (nTranslateBits == 0 && pob.forceOneBitZeroTranslate)
			nTranslateBits = 1;

		writeUBits(nTranslateBits, 5);
		writeSBits(m.translateX, nTranslateBits);
		writeSBits(m.translateY, nTranslateBits);

		flushBits();
	}

	void writeColorTransform(ref ColorTransform c)
	{
		writeBit(c.hasAdd);
		writeBit(c.hasMult);

		uint nBits = c.getNumBits();
		writeUBits(nBits, 4);

		if (c.hasMult)
		{
			writeSBits(c.redMultTerm, nBits);
			writeSBits(c.greenMultTerm, nBits);
			writeSBits(c.blueMultTerm, nBits);
			if (c.hasAlpha)
				writeSBits(c.alphaMultTerm, nBits);
		}

		if (c.hasAdd)
		{
			writeSBits(c.redAddTerm, nBits);
			writeSBits(c.greenAddTerm, nBits);
			writeSBits(c.blueAddTerm, nBits);
			if (c.hasAlpha)
				writeSBits(c.alphaAddTerm, nBits);
		}

		flushBits();
	}

	void writeFilterList(ref Filter[] filterList)
	{
		enforce(filterList.length < 256, "Too many filters");

		writeU8(cast(ubyte)filterList.length);

		foreach (ref f; filterList)
		{
			writeU8(f.type);

			switch(f.type)
			{
			case FilterType.DropShadow:
				writeDropShadowFilter(f.DropShadowFilter);
				break;
			case FilterType.Blur:
				writeBlurFilter(f.BlurFilter);
				break;
			case FilterType.Glow:
				writeGlowFilter(f.GlowFilter);
				break;
			case FilterType.Bevel:
				writeBevelFilter(f.BevelFilter);
				break;
			case FilterType.GradientGlow:
				writeGradientGlowFilter(f.GradientGlowFilter);
				break;
			case FilterType.Convolution:
				writeConvolutionFilter(f.ConvolutionFilter);
				break;
			case FilterType.ColorMatrix:
				writeColorMatrixFilter(f.ColorMatrixFilter);
				break;
			case FilterType.GradientBevel:
				writeGradientBevelFilter(f.GradientBevelFilter);
				break;
			default:
				throw new Exception("Unknown filter type!");
				break;
			}
		}
	}

	void writeDropShadowFilter(ref Filter._DropShadowFilter f)
	{
		writeRgba(f.color);
		writeS32(f.blurX);
		writeS32(f.blurY);
		writeS32(f.angle);
		writeS32(f.distance);
		writeU16(f.strength);
		writeU8(f.flags);
	}

	void writeBlurFilter(ref Filter._BlurFilter f)
	{
		writeS32(f.blurX);
		writeS32(f.blurY);
		writeU8(f.passes);
	}

	void writeGlowFilter(ref Filter._GlowFilter f)
	{
		writeRgba(f.color);
		writeS32(f.blurX);
		writeS32(f.blurY);
		writeU16(f.strength);
		writeU8(f.flags);
	}

	void writeBevelFilter(ref Filter._BevelFilter f)
	{
		writeRgba(f.highlightColor);
		writeRgba(f.shadowColor);
		writeS32(f.blurX);
		writeS32(f.blurY);
		writeS32(f.angle);
		writeS32(f.distance);
		writeU16(f.strength); // fixed 8.8
		writeU8(f.flags); // several fields
	}

	void writeGradientGlowFilter(ref Filter._GradientGlowFilter f)
	{
		writeU8(f.numColors);
		for (uint i = 0; i < f.numColors; ++i)
			writeRgba(f.gradientColors[i]);
		for (uint i = 0; i < f.numColors; ++i)
			writeU8(f.gradientRatio[i]);
		writeS32(f.blurX);
		writeS32(f.blurY);
		writeS32(f.angle);
		writeS32(f.distance);
		writeU16(f.strength); // fixed 8.8
		writeU8(f.flags); // several fields
	}

	void writeConvolutionFilter(ref Filter._ConvolutionFilter f)
	{
		writeU8(f.matrixX);
		writeU8(f.matrixY);
		writeFloat(f.divisor);
		writeFloat(f.bias);
		for (int i = 0; i < f.matrix.length; ++i)
			writeFloat(f.matrix[i]);
		writeRgba(f.color);
		writeU8(f.flags); // several fields
	}

	void writeColorMatrixFilter(ref Filter._ColorMatrixFilter f)
	{
		for (int i = 0; i < 20; ++i)
			writeFloat(f.values[i]);
	}

	void writeGradientBevelFilter(ref Filter._GradientBevelFilter f)
	{
		writeU8(f.numColors);
		for (uint i = 0; i < f.numColors; ++i)
			writeRgba(f.gradientColors[i]);
		for (uint i = 0; i < f.numColors; ++i)
			writeU8(f.gradientRatio[i]);
		writeS32(f.blurX);
		writeS32(f.blurY);
		writeS32(f.angle);
		writeS32(f.distance);
		writeU16(f.strength); // fixed 8.8
		writeU8(f.flags); // several fields
	}

	void writeClipEventFlags(uint flags)
	{
		if (pob.swfVersion > 5)
			writeU32(flags);
		else
			writeU16(cast(ushort)flags);
	}

	void writeClipActions(ref ClipActions c)
	{
		writeU16(0);
		writeClipEventFlags(c.allEventFlags);

		foreach (ref r; c.clipActionRecords)
			writeClipActionRecord(r);

		writeClipEventFlags(0);  // 0 is ClipActionEndFlag
	}

	void writeClipActionRecord(ref ClipActionRecord r)
	{
		writeClipEventFlags(r.eventFlags);

		if (r.eventFlags & 0x00020000) // keyPress
		{
			writeU32(r.getActionsLength() + 1);
			writeU8(r.keyCode);
		}
		else
		{
			writeU32(r.getActionsLength());
		}

		foreach (ref a; r.actions)
			writeAction(a);
	}

	void writeAction(ref Action a)
	{
		writeU8(a.actionCode);
		if (a.actionCode >= 0x80)
		{
			const uint length = a.data.length;
			enforce(length > 0, "Invalid action data!");
			writeExact(a.data.ptr, length);
		}
	}
}
