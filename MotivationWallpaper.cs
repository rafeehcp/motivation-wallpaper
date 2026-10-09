using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Runtime.InteropServices;
namespace Motivation {
 [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left,Top,Right,Bottom; }
 [ComImport,Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
 interface IDesktopWallpaper {
  void SetWallpaper([MarshalAs(UnmanagedType.LPWStr)]string id,[MarshalAs(UnmanagedType.LPWStr)]string path);
  [return:MarshalAs(UnmanagedType.LPWStr)]string GetWallpaper([MarshalAs(UnmanagedType.LPWStr)]string id);
  [return:MarshalAs(UnmanagedType.LPWStr)]string GetMonitorDevicePathAt(uint index);
  uint GetMonitorDevicePathCount();void GetMonitorRECT([MarshalAs(UnmanagedType.LPWStr)]string id,out Rect rect);
  void SetBackgroundColor(uint color);uint GetBackgroundColor();void SetPosition(int position);int GetPosition();
 }
 public class Monitor {public string Id;public int Width,Height;}
 public sealed class Desktop:IDisposable {
  IDesktopWallpaper api=(IDesktopWallpaper)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("C2CF3110-460E-4FC1-B9D0-8A1C0C9CC4BD")));
  public Monitor[] Monitors(){
   var result=new List<Monitor>();uint count=api.GetMonitorDevicePathCount();
   for(uint i=0;i<count;i++){
    string id=api.GetMonitorDevicePathAt(i);Rect r;
    try{api.GetMonitorRECT(id,out r);}
    catch(COMException error){
     // Windows can retain an unavailable legacy monitor after switching users.
     // Its rectangle query returns E_FAIL; keep enumerating the working screens.
     if(error.ErrorCode==unchecked((int)0x80004005))continue;
     throw;
    }
    if(r.Right>r.Left&&r.Bottom>r.Top)result.Add(new Monitor{Id=id,Width=r.Right-r.Left,Height=r.Bottom-r.Top});
   }
   return result.ToArray();
  }
  public string Get(string id){return api.GetWallpaper(id);}public void Set(string id,string path){api.SetWallpaper(id,path);}
  public int Position(){return api.GetPosition();}public void SetPosition(int position){api.SetPosition(position);}
  public void Dispose(){if(api!=null){Marshal.ReleaseComObject(api);api=null;}}
 }
 // The app icon: a white quotation mark over hills on a rounded sky tile.
 public static class AppIcon {
  static readonly int[] Sizes={16,24,32,48,64,256};
  public static Bitmap Draw(int size){
   var bitmap=new Bitmap(size,size,PixelFormat.Format32bppArgb);
   using(var g=Graphics.FromImage(bitmap)){
    g.SmoothingMode=SmoothingMode.AntiAlias;g.PixelOffsetMode=PixelOffsetMode.HighQuality;g.Clear(Color.Transparent);
    float s=size,inset=size>=48?s*0.04f:0.5f;bool small=size<32;
    var area=new RectangleF(inset,inset,s-2*inset,s-2*inset);
    using(var tile=Rounded(area,area.Width*0.22f)){
     using(var sky=new LinearGradientBrush(area,Color.FromArgb(0,95,184),Color.FromArgb(120,196,242),LinearGradientMode.Vertical))g.FillPath(sky,tile);
     g.SetClip(tile);
     // Small sizes keep one hill so the shapes stay distinct.
     if(!small)using(var back=Hill(s,0.70f,0.60f,0.63f,0.56f,0.58f))using(var brush=new SolidBrush(Color.FromArgb(95,175,126)))g.FillPath(brush,back);
     using(var front=Hill(s,0.80f,0.66f,0.74f,0.76f,0.72f))using(var brush=new SolidBrush(Color.FromArgb(46,125,91)))g.FillPath(brush,front);
     using(var quote=new GraphicsPath()){
      quote.AddString("“",new FontFamily("Georgia"),(int)FontStyle.Bold,100f,PointF.Empty,StringFormat.GenericTypographic);
      var bounds=quote.GetBounds();float height=s*(small?0.50f:0.40f),scale=height/bounds.Height;
      using(var m=new Matrix()){
       m.Translate(s*0.5f,s*(small?0.36f:0.35f));m.Scale(scale,scale);m.Translate(-(bounds.X+bounds.Width/2),-(bounds.Y+bounds.Height/2));
       quote.Transform(m);
      }
      g.FillPath(Brushes.White,quote);
     }
    }
   }
   return bitmap;
  }
  static GraphicsPath Rounded(RectangleF r,float radius){
   var path=new GraphicsPath();float d=radius*2;
   path.AddArc(r.X,r.Y,d,d,180,90);path.AddArc(r.Right-d,r.Y,d,d,270,90);path.AddArc(r.Right-d,r.Bottom-d,d,d,0,90);path.AddArc(r.X,r.Bottom-d,d,d,90,90);path.CloseFigure();
   return path;
  }
  // A hill whose top runs from left through a peak and a dip to right, as fractions of the size.
  static GraphicsPath Hill(float s,float left,float peak,float dip,float rise,float right){
   var path=new GraphicsPath();
   path.AddBezier(0,s*left,s*0.22f,s*peak,s*0.42f,s*peak,s*0.6f,s*dip);
   path.AddBezier(s*0.6f,s*dip,s*0.76f,s*(dip+0.06f),s*0.88f,s*rise,s,s*right);
   path.AddLine(s,s*right,s,s);path.AddLine(s,s,0,s);path.CloseFigure();
   return path;
  }
  // Writes a multi-size .ico: PNG for 256 pixels, and the classic 32-bit bitmap format below,
  // which every icon reader accepts (System.Drawing, for one, cannot decode small PNG entries).
  public static void Save(string path){
   var images=new List<byte[]>();
   foreach(var size in Sizes)using(var bitmap=Draw(size)){
    if(size>=256)using(var stream=new System.IO.MemoryStream()){bitmap.Save(stream,ImageFormat.Png);images.Add(stream.ToArray());}
    else images.Add(IconBitmap(bitmap));
   }
   using(var writer=new System.IO.BinaryWriter(System.IO.File.Create(path))){
    writer.Write((short)0);writer.Write((short)1);writer.Write((short)Sizes.Length);
    int offset=6+16*Sizes.Length;
    for(int i=0;i<Sizes.Length;i++){
     var edge=(byte)(Sizes[i]>=256?0:Sizes[i]);
     writer.Write(edge);writer.Write(edge);writer.Write((byte)0);writer.Write((byte)0);writer.Write((short)1);writer.Write((short)32);writer.Write(images[i].Length);writer.Write(offset);
     offset+=images[i].Length;
    }
    foreach(var image in images)writer.Write(image);
   }
  }
  // An icon bitmap is a BITMAPINFOHEADER with doubled height, bottom-up BGRA rows, then a 1-bit mask.
  // The mask stays clear because the alpha channel already carries transparency.
  static byte[] IconBitmap(Bitmap bitmap){
   int size=bitmap.Width,maskStride=((size+31)/32)*4;
   using(var stream=new System.IO.MemoryStream())using(var writer=new System.IO.BinaryWriter(stream)){
    writer.Write(40);writer.Write(size);writer.Write(size*2);writer.Write((short)1);writer.Write((short)32);
    writer.Write(0);writer.Write(size*size*4+maskStride*size);writer.Write(0);writer.Write(0);writer.Write(0);writer.Write(0);
    var data=bitmap.LockBits(new Rectangle(0,0,size,size),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
    try{
     var row=new byte[size*4];
     for(int y=size-1;y>=0;y--){Marshal.Copy(IntPtr.Add(data.Scan0,y*data.Stride),row,0,row.Length);writer.Write(row);}
    }finally{bitmap.UnlockBits(data);}
    writer.Write(new byte[maskStride*size]);
    return stream.ToArray();
   }
  }
 }
 public static class Renderer {
  public static void GenerateBackground(string output,int width,int height,string theme,int seed){
   var random=new Random(seed);
   Color top,bottom;
   if((theme??"").StartsWith("Bold",StringComparison.OrdinalIgnoreCase)){top=Color.FromArgb(57,27,70);bottom=Color.FromArgb(156,70,60);}
   else if((theme??"").StartsWith("Calm",StringComparison.OrdinalIgnoreCase)){top=Color.FromArgb(21,47,69);bottom=Color.FromArgb(65,119,125);}
   else{top=Color.FromArgb(21,46,43);bottom=Color.FromArgb(81,116,82);}
   using(var bitmap=new Bitmap(width,height))using(var g=Graphics.FromImage(bitmap)){
    g.SmoothingMode=SmoothingMode.AntiAlias;
    using(var gradient=new LinearGradientBrush(new Rectangle(0,0,width,height),top,bottom,60+random.Next(60)))g.FillRectangle(gradient,0,0,width,height);
    // Broad translucent forms keep the quote area visually quiet.
    float radius=Math.Min(width,height)*(.38f+(float)random.NextDouble()*.2f);
    float cx=width*.72f,cy=height*(.18f+(float)random.NextDouble()*.16f);
    using(var glowPath=new GraphicsPath()){
     glowPath.AddEllipse(cx-radius,cy-radius,radius*2,radius*2);
     using(var glow=new PathGradientBrush(glowPath)){glow.CenterColor=Color.FromArgb(60,239,214,174);glow.SurroundColors=new[]{Color.FromArgb(0,239,214,174)};g.FillPath(glow,glowPath);}
    }
    for(int layer=0;layer<4;layer++){
     var points=new List<PointF>();points.Add(new PointF(-width*.1f,height));
     for(int i=-1;i<=9;i++){float x=width*i/8f;float y=height*(.65f+layer*.07f)+(float)Math.Sin(i*.7+seed%29+layer)*height*.035f;points.Add(new PointF(x,y));}
     points.Add(new PointF(width*1.1f,height));
     using(var hill=new SolidBrush(Color.FromArgb(28+layer*13,8,21,29)))g.FillPolygon(hill,points.ToArray());
    }
    bitmap.Save(output,ImageFormat.Png);
   }
  }
  public static string FontForTheme(string theme){
   string preferred=(theme??"").StartsWith("Bold",StringComparison.OrdinalIgnoreCase)?"Bahnschrift":(theme??"").StartsWith("Calm",StringComparison.OrdinalIgnoreCase)?"Georgia":"Segoe UI";
   using(var installed=new InstalledFontCollection()){foreach(var family in installed.Families)if(family.Name==preferred)return preferred;}
   return "Segoe UI";
  }
  static string Balance(Graphics g,string text,Font font,float maxWidth){
   string[] words=text.Split(new[]{' '},StringSplitOptions.RemoveEmptyEntries);string best=text;double bestCost=Double.MaxValue;int minLines=Int32.MaxValue;
   for(float width=maxWidth;width>=maxWidth*.60f;width-=maxWidth*.02f){
    var lines=new List<string>();string line="";
    foreach(string word in words){string next=line.Length==0?word:line+" "+word;if(line.Length>0&&g.MeasureString(next,font).Width>width){lines.Add(line);line=word;}else line=next;}if(line.Length>0)lines.Add(line);
    if(lines.Count>minLines)continue;if(lines.Count<minLines){minLines=lines.Count;bestCost=Double.MaxValue;}
    double sum=0;foreach(string l in lines)sum+=g.MeasureString(l,font).Width;double mean=sum/lines.Count,cost=0;foreach(string l in lines){double diff=g.MeasureString(l,font).Width-mean;cost+=diff*diff;}
    if(cost<bestCost){bestCost=cost;best=String.Join("\n",lines.ToArray());}
   }return best;
  }
  public static float Render(string background,string output,int width,int height,string quote,string author,string credit){
   return Render(background,output,width,height,quote,author,credit,"");
  }
  public static float Render(string background,string output,int width,int height,string quote,string author,string credit,string theme){
   return Render(background,output,width,height,quote,author,credit,theme,"Center");
  }
  // Left and Right keep the other side clear for desktop icons. Center is the original layout.
  public static float Render(string background,string output,int width,int height,string quote,string author,string credit,string theme,string position){
   bool left=String.Equals(position,"Left",StringComparison.OrdinalIgnoreCase),right=String.Equals(position,"Right",StringComparison.OrdinalIgnoreCase);
   string familyName=FontForTheme(theme);
   FontStyle style=(theme??"").StartsWith("Bold",StringComparison.OrdinalIgnoreCase)?FontStyle.Bold:FontStyle.Regular;
   using(var family=new FontFamily(familyName)){if(!family.IsStyleAvailable(style))style=FontStyle.Regular;}
   using(var bitmap=new Bitmap(width,height))using(var g=Graphics.FromImage(bitmap)){
    g.Clear(Color.FromArgb(23,38,43));g.SmoothingMode=SmoothingMode.AntiAlias;g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.TextRenderingHint=TextRenderingHint.AntiAliasGridFit;
    if(!String.IsNullOrEmpty(background))using(var source=Image.FromFile(background)){float scale=Math.Max((float)width/source.Width,(float)height/source.Height);float w=source.Width*scale,h=source.Height*scale;g.DrawImage(source,new RectangleF((width-w)/2,(height-h)/2,w,h));}
    // White source pixels become <=90; white text has >7:1 contrast.
    using(var shade=new SolidBrush(Color.FromArgb(165,0,0,0)))g.FillRectangle(shade,0,0,width,height);
    float unit=Math.Min(width,height),x=width*.24f,boxWidth=width*.67f,size=unit*.049f,minimum=unit*.034f;
    // Portrait screens are too narrow for a half-width box.
    if(left||right){boxWidth=width<height?width*.67f:width*.50f;x=left?width*.06f:width*.94f-boxWidth;}
    Font font=null;SizeF measured=SizeF.Empty;
    using(var format=new StringFormat(StringFormat.GenericTypographic)){
     format.FormatFlags=StringFormatFlags.LineLimit;
     if(right)format.Alignment=StringAlignment.Far;
     string wrapped=quote;
     for(;size>=minimum;size-=1f){if(font!=null)font.Dispose();font=new Font(familyName,size,style,GraphicsUnit.Pixel);wrapped=Balance(g,quote,font,boxWidth);measured=g.MeasureString(wrapped,font,new SizeF(boxWidth,10000),format);bool fits=measured.Height<=height*.40f;foreach(string word in quote.Split(' '))if(g.MeasureString(word,font).Width>boxWidth)fits=false;if(fits)break;}
     if(size<minimum){if(font!=null)font.Dispose();throw new InvalidOperationException("Quote is too long for a readable layout.");}
     using(font)using(var authorFont=new Font("Segoe UI",unit*.021f,FontStyle.Regular,GraphicsUnit.Pixel)){
      var authorSize=g.MeasureString(author,authorFont,new SizeF(boxWidth,10000),format);float gap=unit*.035f,total=measured.Height+gap+authorSize.Height;if(total>height*.65f)throw new InvalidOperationException("Quote and author do not fit.");float y=(height-total)*.49f;
      using(var accent=new SolidBrush(Color.FromArgb(204,220,205)))g.FillRectangle(accent,right?x+boxWidth-unit*.055f:x,y-unit*.043f,unit*.055f,3);
      g.DrawString(wrapped,font,Brushes.White,new RectangleF(x,y,boxWidth,measured.Height+5),format);g.DrawString(author,authorFont,Brushes.White,new RectangleF(x,y+measured.Height+gap,boxWidth,authorSize.Height+5),format);
     }
    }
    using(var foot=new Font("Segoe UI",Math.Max(12,unit*.012f),FontStyle.Regular,GraphicsUnit.Pixel))g.DrawString(credit,foot,Brushes.White,new RectangleF(width*.08f,height*.92f,width*.84f,height*.06f));
    bitmap.Save(output,ImageFormat.Png);return size;
   }
  }
 }
}
