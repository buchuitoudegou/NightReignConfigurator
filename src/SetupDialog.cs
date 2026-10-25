using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;
using System.Collections.Generic;
using System.Web.Script.Serialization;
using Microsoft.Win32;

class SetupDialog : Form {
 readonly string home=AppDomain.CurrentDomain.BaseDirectory;
 readonly Dictionary<string,TextBox> fields=new Dictionary<string,TextBox>();
 readonly JavaScriptSerializer json=new JavaScriptSerializer();
 readonly Button save=new Button();
 bool busy;
 public SetupDialog(){
  Text="首次配置 / 环境设置";ClientSize=new Size(820,440);MinimumSize=new Size(836,479);StartPosition=FormStartPosition.CenterParent;
  Font=new Font("Microsoft YaHei UI",9);AutoScaleMode=AutoScaleMode.Dpi;
  var layout=new TableLayoutPanel{Dock=DockStyle.Fill,Padding=new Padding(18),ColumnCount=3,RowCount=8};
  layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,125));layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,80));Controls.Add(layout);
  var help=new Label{Text="选择已安装的依赖；不会下载或打包游戏及无缝文件。\nPowerShell 需要 .NET 10 运行时（建议 PowerShell 7.6）。",Dock=DockStyle.Fill};layout.Controls.Add(help,0,0);layout.SetColumnSpan(help,3);layout.RowStyles.Add(new RowStyle(SizeType.Absolute,60));
  string[] keys={"GameExe","SeamlessDll","Me3","Smithbox","PowerShell"};
  string[] labels={"游戏 nightreign.exe","无缝 nrsc.dll","ME3 me3.exe","Smithbox 组件目录","PowerShell pwsh.exe"};
  Dictionary<string,object> old=null;string cfg=Path.Combine(home,"data","config.json");if(File.Exists(cfg))old=json.Deserialize<Dictionary<string,object>>(File.ReadAllText(cfg));
  for(int i=0;i<keys.Length;i++){
   string key=keys[i];layout.RowStyles.Add(new RowStyle(SizeType.Absolute,44));layout.Controls.Add(new Label{Text=labels[i],Dock=DockStyle.Fill,TextAlign=ContentAlignment.MiddleLeft},0,i+1);
   var box=new TextBox{Dock=DockStyle.Fill,Margin=new Padding(3,10,3,3)};fields[key]=box;if(old!=null&&old.ContainsKey(key))box.Text=Convert.ToString(old[key]);layout.Controls.Add(box,1,i+1);
   var browse=new Button{Text="浏览",Dock=DockStyle.Fill};browse.Click+=(s,e)=>{if(key=="Smithbox"){using(var d=new FolderBrowserDialog()){if(d.ShowDialog(this)==DialogResult.OK)box.Text=d.SelectedPath;}}else{using(var d=new OpenFileDialog{Filter=key=="SeamlessDll"?"无缝 DLL|nrsc.dll":"程序|*.exe",CheckFileExists=true}){if(d.ShowDialog(this)==DialogResult.OK)box.Text=d.FileName;}}};layout.Controls.Add(browse,2,i+1);
  }
  var note=new Label{Text="无缝设置沿用 nrsc.dll 旁的 nrsc_settings.ini，不复制或读取密码。\n原始参数由你安装的游戏复制到本程序 data 文件夹。请解压至可写位置。",Dock=DockStyle.Fill};layout.Controls.Add(note,0,6);layout.SetColumnSpan(note,3);layout.RowStyles.Add(new RowStyle(SizeType.Absolute,65));
  save.Text="验证并保存";save.Dock=DockStyle.Fill;layout.Controls.Add(save,1,7);save.Click+=async(s,e)=>{
   busy=true;layout.Enabled=false;
   try{var values=fields.ToDictionary(p=>p.Key,p=>(object)p.Value.Text.Trim().Trim('"'));Directory.CreateDirectory(Path.Combine(home,"data"));string request=Path.Combine(home,"data","setup-request.json");File.WriteAllText(request,json.Serialize(values),new UTF8Encoding(false));
    try{await System.Threading.Tasks.Task.Run(()=>Runner.Run((string)values["PowerShell"],home,"Setup.ps1"," -Request \""+request+"\""));}finally{if(File.Exists(request))File.Delete(request);}
    DialogResult=DialogResult.OK;
   }catch(Exception ex){MessageBox.Show(this,ex.Message,"配置失败");}finally{busy=false;layout.Enabled=true;}
  };
  FormClosing+=(s,e)=>{if(busy)e.Cancel=true;};
  if(old==null)Detect();
  string bundled=Path.Combine(home,"vendor","smithbox");
  if((old==null||!Directory.Exists(fields["Smithbox"].Text))&&File.Exists(Path.Combine(bundled,"Andre.SoulsFormats.dll")))fields["Smithbox"].Text=bundled;
 }
 void Detect(){
  string steam=Convert.ToString(Registry.GetValue(@"HKEY_CURRENT_USER\Software\Valve\Steam","SteamPath",null));
  var roots=new List<string>();if(!String.IsNullOrEmpty(steam))roots.Add(steam);
  string libraries=Path.Combine(steam,"steamapps","libraryfolders.vdf");if(File.Exists(libraries))foreach(System.Text.RegularExpressions.Match m in System.Text.RegularExpressions.Regex.Matches(File.ReadAllText(libraries),"\"path\"\\s+\"([^\"]+)\""))roots.Add(m.Groups[1].Value.Replace("\\\\","\\"));
  foreach(string root in roots){string game=Path.Combine(root,"steamapps","common","ELDEN RING NIGHTREIGN","Game");if(File.Exists(Path.Combine(game,"nightreign.exe"))){fields["GameExe"].Text=Path.Combine(game,"nightreign.exe");foreach(string sub in new[]{"SeamlessCoop","nrsc"}){string dll=Path.Combine(game,sub,"nrsc.dll");if(File.Exists(dll)){fields["SeamlessDll"].Text=dll;break;}}break;}}
  foreach(string key in new[]{"Me3","PowerShell"}){string exe=key=="Me3"?"me3.exe":"pwsh.exe";var dirs=(Environment.GetEnvironmentVariable("PATH")??"").Split(';').Concat(new[]{Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"PowerShell","7")});foreach(string dir in dirs){try{string p=Path.Combine(dir.Trim('"'),exe);if(File.Exists(p)){fields[key].Text=p;break;}}catch(ArgumentException){}}}
 }
}
static class Runner {
 public static string Run(string pwsh,string home,string script,string extra){
  var si=new ProcessStartInfo{FileName=pwsh,Arguments="-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \""+Path.Combine(home,script)+"\""+extra,WorkingDirectory=home,UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true,StandardOutputEncoding=Encoding.UTF8,StandardErrorEncoding=Encoding.UTF8};
  using(var p=Process.Start(si)){var o=p.StandardOutput.ReadToEndAsync();var e=p.StandardError.ReadToEndAsync();p.WaitForExit();System.Threading.Tasks.Task.WaitAll(o,e);if(p.ExitCode!=0)throw new Exception(e.Result+o.Result);return o.Result;}
 }
}
