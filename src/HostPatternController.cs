using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Drawing;
using System.Diagnostics;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Web.Script.Serialization;
using System.Windows.Forms;
class HostPatternController:Form{
 const long SiteRva=0x6aeee5,ManagerRva=0x3c13258;
 const string ExeHash="9545E8732919BB6A63904CB73223641B3C4F9A67869BE5722612ACCA413E8B3A";
 readonly byte[] original={0x48,0x8b,0x05,0x6c,0x43,0x56,0x03,0x44,0x89,0xa0,0x48,0x0b,0,0};
 [DllImport("kernel32.dll",SetLastError=true)]static extern IntPtr OpenProcess(uint a,bool i,int p);
 [DllImport("kernel32.dll",SetLastError=true)]static extern bool ReadProcessMemory(IntPtr h,IntPtr a,byte[] b,UIntPtr l,out UIntPtr n);
 [DllImport("kernel32.dll",SetLastError=true)]static extern bool WriteProcessMemory(IntPtr h,IntPtr a,byte[] b,UIntPtr l,out UIntPtr n);
 [DllImport("kernel32.dll",SetLastError=true)]static extern IntPtr VirtualAllocEx(IntPtr h,IntPtr a,UIntPtr l,uint t,uint p);
 [DllImport("kernel32.dll",SetLastError=true)]static extern bool VirtualProtectEx(IntPtr h,IntPtr a,UIntPtr l,uint p,out uint old);
 [DllImport("kernel32.dll")]static extern bool FlushInstructionCache(IntPtr h,IntPtr a,UIntPtr l);
 [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr h);
 readonly string home=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"data");
 readonly JavaScriptSerializer json=new JavaScriptSerializer();
 readonly Label label=new Label();readonly Button apply=new Button(),remove=new Button();
 readonly Timer timer=new Timer();Process game;IntPtr handle;long imageBase,cave;byte[] patch;bool active;int target;string last="";
 byte[] Read(long addr,int len){var b=new byte[len];UIntPtr n;if(!ReadProcessMemory(handle,new IntPtr(addr),b,(UIntPtr)len,out n)||n.ToUInt64()!=(ulong)len)throw new Exception("读取游戏内存失败。");return b;}
 void Write(long addr,byte[] b){UIntPtr n;if(!WriteProcessMemory(handle,new IntPtr(addr),b,(UIntPtr)b.Length,out n)||n.ToUInt64()!=(ulong)b.Length)throw new Exception("写入失败。");}
 long Manager(){return BitConverter.ToInt64(Read(imageBase+ManagerRva,8),0);}
 bool Lobby(){long m=Manager();return BitConverter.ToInt32(Read(m+0xb48,4),0)==-1&&BitConverter.ToInt32(Read(m+0xb4c,4),0)==-1;}
 static string Hash(string path){using(var s=File.OpenRead(path))using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(s)).Replace("-","");}
 public HostPatternController(){
 Text="房主地图模板控制器 · 测试版";ClientSize=new Size(640,250);Font=new Font("Microsoft YaHei UI",10);StartPosition=FormStartPosition.CenterScreen;
 label.SetBounds(20,18,600,160);label.Text="仅用于房主无缝联机。\n先在配置器生成目标模板配置，再启动游戏并停留圆桌厅。\n点击应用后保持此窗口开启；游戏退出时补丁自动消失。\n尚需联机验证；此程序不替换地图布局，不修改游戏磁盘文件。";Controls.Add(label);
 apply.Text="在圆桌厅应用房主锁定";apply.SetBounds(20,185,290,42);apply.Click+=(s,e)=>{try{Apply();}catch(Exception ex){label.Text=ex.Message;}};Controls.Add(apply);
 remove.Text="解除锁定（圆桌厅）";remove.SetBounds(330,185,290,42);remove.Enabled=false;remove.Click+=(s,e)=>{try{Remove();}catch(Exception ex){label.Text=ex.Message;}};Controls.Add(remove);
 timer.Interval=1000;timer.Tick+=(s,e)=>Poll();timer.Start();
 FormClosing+=(s,e)=>{if(active){try{Remove();}catch(Exception ex){e.Cancel=true;label.Text=ex.Message+"\n请回圆桌厅解除，或退出游戏后再关闭。";}}};
 }
 public static byte[] Build(long cave,long global,long back,int desired){
 var b=new List<byte>();Action<byte[]> put=x=>b.AddRange(x);
 put(new byte[]{0x9c,0x41,0x52,0x41,0x53,0x4d,0x89,0xfa,0x4c,0x8b,0x5d,0xf8});
 int loop=b.Count;put(new byte[]{0x4d,0x39,0xda,0x73,0});int skip=b.Count-1;
 put(new byte[]{0x41,0x81,0x3a});put(BitConverter.GetBytes(desired));put(new byte[]{0x74,0});int found=b.Count-1;
 put(new byte[]{0x49,0x83,0xc2,0x04,0xeb,0});b[b.Count-1]=unchecked((byte)(loop-b.Count));
 int yes=b.Count;b[found]=(byte)(yes-found-1);put(new byte[]{0x41,0xbc});put(BitConverter.GetBytes(desired));
 put(new byte[]{0x49,0xba});put(BitConverter.GetBytes(cave+512));put(new byte[]{0x41,0xff,0x02,0xeb,0});int done=b.Count-1;
 int no=b.Count;b[skip]=(byte)(no-skip-1);put(new byte[]{0x49,0xba});put(BitConverter.GetBytes(cave+516));put(new byte[]{0x41,0xff,0x02});
 b[done]=(byte)(b.Count-done-1);put(new byte[]{0x41,0x5b,0x41,0x5a,0x9d,0x48,0xb8});put(BitConverter.GetBytes(global));
 put(new byte[]{0x48,0x8b,0x00,0x44,0x89,0xa0,0x48,0x0b,0,0,0xff,0x25,0,0,0,0});put(BitConverter.GetBytes(back));return b.ToArray();
 }
 void Apply(){
 if(active)throw new Exception("已经应用。请先解除再修改目标。");
 string config=Path.Combine(home,"host-selection.json");if(!File.Exists(config))throw new Exception("请先在配置器启用房主锁定并生成。");
 var cfg=json.Deserialize<Dictionary<string,object>>(File.ReadAllText(config));if(cfg["PatternId"]==null)throw new Exception("当前生成配置没有启用房主锁定。");
 target=Convert.ToInt32(cfg["PatternId"]);if(!((target>=0&&target<=319)||(target>=1000&&target<=1199)))throw new Exception("无效模板编号。");
 if(Hash((string)cfg["Output"])!=(string)cfg["Hash"])throw new Exception("生成后的参数文件已变化，请重新生成。");
 var games=Process.GetProcessesByName("nightreign");if(games.Length!=1)throw new Exception("请启动一个无缝联机游戏进程。");game=games[0];
 if(game.StartTime.ToUniversalTime()<DateTime.Parse((string)cfg["GeneratedUtc"]).ToUniversalTime())throw new Exception("参数生成后必须重新启动游戏。");
 if(!game.Modules.Cast<ProcessModule>().Any(m=>m.ModuleName.Equals("nrsc.dll",StringComparison.OrdinalIgnoreCase)))throw new Exception("未检测到无缝联机模块。");
 if(Hash(game.MainModule.FileName)!=ExeHash)throw new Exception("游戏版本不匹配，拒绝使用旧偏移。");
 if(handle!=IntPtr.Zero)CloseHandle(handle);handle=OpenProcess(0x438,false,game.Id);if(handle==IntPtr.Zero)throw new Exception("无法打开游戏进程。");imageBase=game.MainModule.BaseAddress.ToInt64();
 if(!Lobby())throw new Exception("请在圆桌厅应用，不能在远征中修改。");
 long site=imageBase+SiteRva;if(!Read(site,14).SequenceEqual(original))throw new Exception("模板选择指令已被其他修改覆盖，拒绝应用。");
 cave=VirtualAllocEx(handle,IntPtr.Zero,(UIntPtr)4096,0x3000,0x40).ToInt64();if(cave==0)throw new Exception("无法分配补丁内存。");
 Write(cave,Build(cave,imageBase+ManagerRva,site+14,target));patch=new byte[14];patch[0]=0xff;patch[1]=0x25;Array.Copy(BitConverter.GetBytes(cave),0,patch,6,8);
 uint protect;if(!VirtualProtectEx(handle,new IntPtr(site),(UIntPtr)14,0x40,out protect))throw new Exception("无法更新指令保护。");
 try{Write(site,patch);if(!Read(site,14).SequenceEqual(patch))throw new Exception("补丁回读失败。");active=true;}catch{Write(site,original);throw;}finally{uint ignored;VirtualProtectEx(handle,new IntPtr(site),(UIntPtr)14,protect,out ignored);FlushInstructionCache(handle,new IntPtr(site),(UIntPtr)14);}
 apply.Enabled=false;remove.Enabled=true;label.Text="已应用房主模板锁定："+target+"\n下一次出击生效。目标不在候选池时会保留原抽选并报告未命中。\n请保持此窗口开启；不要以访客身份加入别人的远征。";
 }
 void Remove(){if(!active)return;if(game.HasExited){active=false;return;}if(!Lobby())throw new Exception("请返回圆桌厅再解除锁定。");long site=imageBase+SiteRva;if(!Read(site,14).SequenceEqual(patch))throw new Exception("补丁已被其他程序修改，拒绝覆盖。");uint old;if(!VirtualProtectEx(handle,new IntPtr(site),(UIntPtr)14,0x40,out old))throw new Exception("解除失败。");try{Write(site,original);}finally{uint x;VirtualProtectEx(handle,new IntPtr(site),(UIntPtr)14,old,out x);FlushInstructionCache(handle,new IntPtr(site),(UIntPtr)14);}active=false;apply.Enabled=true;remove.Enabled=false;label.Text="已解除房主锁定。";}
 void Poll(){if(!active)return;try{if(game.HasExited){active=false;apply.Enabled=true;remove.Enabled=false;label.Text="游戏已退出，内存补丁已消失。";return;}
 long m=Manager();int pattern=BitConverter.ToInt32(Read(m+0xb4c,4),0);uint seed=BitConverter.ToUInt32(Read(m+0xb54,4),0);uint hit=BitConverter.ToUInt32(Read(cave+512,4),0),miss=BitConverter.ToUInt32(Read(cave+516,4),0);
 label.Text="房主目标模板："+target+"\n本局模板："+pattern+"   远征种子候选值："+seed+"\n选取命中："+hit+"   不在候选池："+miss+"\n"+(pattern<0?"圆桌厅待出击。":"请核对本局地图；队友一致性仍需实测。");
 string key=game.Id+":"+pattern+":"+seed;if(pattern>=0&&key!=last){Directory.CreateDirectory(Path.Combine(home,"history"));File.AppendAllText(Path.Combine(home,"history","host-patterns.jsonl"),json.Serialize(new{TimeUtc=DateTime.UtcNow.ToString("o"),PatternId=pattern,SeedCandidate=seed,Target=target,Hits=hit,Misses=miss})+Environment.NewLine);last=key;}
 }catch(Exception ex){label.Text="读取状态失败："+ex.Message;}}
 [STAThread]static void Main(string[] args){if(args.Length==1&&args[0]=="--dump-test-code"){File.WriteAllBytes("host-code-test.bin",Build(0x180000000,0x143c13258,0x1406aeef3,88));return;}bool first;using(var single=new System.Threading.Mutex(true,"Local\\NightreignHostPatternController",out first)){if(!first)return;Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);Application.Run(new HostPatternController());}}
}
