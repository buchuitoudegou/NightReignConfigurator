using System;
using System.IO;
using System.Text;
using System.Linq;
using System.Drawing;
using System.Windows.Forms;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

class Configurator : Form {
 readonly string home=AppDomain.CurrentDomain.BaseDirectory;
 readonly string dataHome=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"data");
 readonly JavaScriptSerializer json=new JavaScriptSerializer();
 readonly CheckBox[] bosses=new CheckBox[10];
 readonly CheckBox everdark=new CheckBox();
 readonly CheckBox fixedPattern=new CheckBox();
 readonly TextBox patternInput=new TextBox();
 readonly Label patternInfo=new Label();
 Dictionary<int,Pattern> patterns;
 class Pattern {public int Id {get;set;} public int Boss {get;set;} public int Terrain {get;set;} public int Set {get;set;} public int Night1 {get;set;} public int Night2 {get;set;}}
 readonly CheckBox[] terrainChecks=new CheckBox[5];
 readonly ComboBox weighting=new ComboBox();
 readonly Label summary=new Label(), status=new Label(), outputLabel=new Label();
 readonly Button generate=new Button();
 readonly ProgressBar progress=new ProgressBar();
 readonly Panel settings=new Panel();
 Dictionary<string,object> config;
 string output;
 bool busy;
 readonly string[] names={"Gladius · 三头野兽","Adel · 裂颚","Gnoster · 慧心虫","Maris · 兆头","Libra · 平衡律法的魔物","Fulghor · 暗中飞驰的猎人","Caligo · 雾中裂缝","Heolstor · 黑夜之形","Harmonia · 安定者们","Straghess · 废弃物之王"};
 readonly string[] terrains={"原版随机（不固定）","雪山 · Mountaintop","火山 · The Crater","腐败 · Rotted Woods","大空洞 · Great Hollow","隐城 · Shrouded City"};
 [STAThread] static void Main(string[] args){
  Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
  try{if(!File.Exists(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"data","config.json"))){using(var setup=new SetupDialog()){if(setup.ShowDialog()!=DialogResult.OK)return;}}Application.Run(new Configurator(args));}catch(Exception e){MessageBox.Show(e.Message,"启动失败",MessageBoxButtons.OK,MessageBoxIcon.Error);}
 }
 Label TextLabel(string text,int x,int y,int w,int h,float size,bool bold){
  Label l=new Label{Text=text,Location=new Point(x,y),Size=new Size(w,h),Font=new Font("Microsoft YaHei UI",size,bold?FontStyle.Bold:FontStyle.Regular),ForeColor=Color.FromArgb(35,44,59)};return l;
 }
 Button ActionButton(string text,int x,int y,int w){return new Button{Text=text,Location=new Point(x,y),Size=new Size(w,34),FlatStyle=FlatStyle.Standard,BackColor=Color.White};}
 public Configurator(string[] args){
  config=json.Deserialize<Dictionary<string,object>>(File.ReadAllText(Path.Combine(dataHome,"config.json"),Encoding.UTF8));
  patterns=json.Deserialize<Pattern[]>(File.ReadAllText(Path.Combine(dataHome,"patterns.json"),Encoding.UTF8)).ToDictionary(p=>p.Id);
  output=(string)config["Output"];
  if(args.Length==2 && args[0]=="--test-output")output=Path.GetFullPath(args[1]);
  Text="黑夜君临 · 远征配置器";ClientSize=new Size(880,815);MinimumSize=new Size(840,690);FormBorderStyle=FormBorderStyle.Sizable;MaximizeBox=true;
  StartPosition=FormStartPosition.CenterScreen;AutoScaleMode=AutoScaleMode.Dpi;Font=new Font("Microsoft YaHei UI",9F);BackColor=Color.FromArgb(244,246,250);
  Controls.Add(TextLabel("远征，由你选择",28,20,350,43,23,true));
  Controls.Add(TextLabel("深夜模式配置  /  每次从原始参数重新生成",30,66,620,25,10,false));
  Button setupButton=ActionButton("环境设置",390,20,130);setupButton.Click+=(s,e)=>{if(busy)return;using(var d=new SetupDialog()){if(d.ShowDialog(this)==DialogResult.OK){config=json.Deserialize<Dictionary<string,object>>(File.ReadAllText(Path.Combine(dataHome,"config.json")));output=(string)config["Output"];outputLabel.Text="输出："+output;}}};Controls.Add(setupButton);
  Button iniButton=ActionButton("无缝设置",530,20,130);iniButton.Click+=(s,e)=>{try{Process.Start(new ProcessStartInfo{FileName="notepad.exe",Arguments="\""+(string)config["SeamlessIni"]+"\"",UseShellExecute=true});}catch(Exception ex){MessageBox.Show(ex.Message);}};Controls.Add(iniButton);
  Button launchButton=ActionButton("启动无缝",685,62,165);launchButton.Click+=async(s,e)=>{if(busy)return;busy=true;launchButton.Enabled=false;generate.Enabled=false;try{await Task.Run(()=>Runner.Run((string)config["PowerShell"],home,"Launch.ps1",""));status.Text="启动命令已完成";}catch(Exception ex){MessageBox.Show(ex.Message,"启动失败");}finally{busy=false;launchButton.Enabled=true;RefreshSummary();}};Controls.Add(launchButton);
  Button hostButton=ActionButton("房主控制器",685,20,165);hostButton.Click+=(s,e)=>{try{Process.Start(new ProcessStartInfo{FileName=Path.Combine(home,"Host-Pattern-Controller.exe"),UseShellExecute=true});}catch(Exception ex){MessageBox.Show(ex.Message);}};Controls.Add(hostButton);
  settings.SetBounds(22,105,836,526);settings.BackColor=Color.White;settings.Anchor=AnchorStyles.Top|AnchorStyles.Bottom|AnchorStyles.Left|AnchorStyles.Right;settings.AutoScroll=true;settings.AutoScrollMinSize=new Size(0,690);Controls.Add(settings);
  settings.Controls.Add(TextLabel("01   选择夜王",18,12,400,30,12,true));
  settings.Controls.Add(TextLabel("可多选；全部不选时，保留原版夜王池和相对权重。",18,45,790,24,9,false));
  for(int i=0;i<10;i++){
   int id=i;CheckBox c=new CheckBox{Text=names[i],Location=new Point(22+(i%2)*402,79+(i/2)*36),Size=new Size(395,31),AutoSize=false};
   c.CheckedChanged+=(s,e)=>RefreshSummary();bosses[i]=c;settings.Controls.Add(c);
  }
  Button all=ActionButton("全选",625,6,82),clear=ActionButton("清空",717,6,82);
  all.Click+=(s,e)=>{if(fixedPattern.Checked)return;foreach(var c in bosses)c.Checked=true;};clear.Click+=(s,e)=>{if(fixedPattern.Checked)return;foreach(var c in bosses)c.Checked=false;};settings.Controls.Add(all);settings.Controls.Add(clear);
  settings.Controls.Add(TextLabel("多选概率",22,269,100,30,9,true));
  weighting.SetBounds(128,265,324,30);weighting.DropDownStyle=ComboBoxStyle.DropDownList;weighting.Items.AddRange(new object[]{"等概率：所选夜王系列机会相同","原版权重：保留所选系列的原始比例"});weighting.SelectedIndex=0;weighting.SelectedIndexChanged+=(s,e)=>RefreshSummary();settings.Controls.Add(weighting);
  settings.Controls.Add(TextLabel("02   夜王版本",18,315,300,28,12,true));
  everdark.Text="固定永夜版本";everdark.SetBounds(22,351,280,28);everdark.CheckedChanged+=(s,e)=>RefreshSummary();settings.Controls.Add(everdark);
  settings.Controls.Add(TextLabel("开启后排除 Heolstor、Straghess；它们没有独立的永夜条目。",22,384,780,24,9,false));
  settings.Controls.Add(TextLabel("03   特异地形",18,424,300,28,12,true));
  string[] terrainNames={"雪山","火山","腐败","大空洞（DLC）","隐城"};
  for(int i=0;i<5;i++){
   var c=new CheckBox{Text=terrainNames[i],Location=new Point(22+i*158,459),Size=new Size(154,30)};
   terrainChecks[i]=c;c.CheckedChanged+=(s,e)=>RefreshSummary();settings.Controls.Add(c);
  }
  settings.Controls.Add(TextLabel("可多选；选中地形保留原版相对权重。全部不选时恢复原版随机（含普通地形）。",22,495,795,24,9,false));
  settings.Controls.Add(TextLabel("04   房主固定 Map pattern（待联机验证）",18,540,720,30,12,true));
  fixedPattern.Text="启用房主锁定";fixedPattern.SetBounds(22,579,160,30);fixedPattern.CheckedChanged+=(s,e)=>RefreshSummary();settings.Controls.Add(fixedPattern);
  patternInput.SetBounds(190,578,150,30);patternInput.Enabled=false;patternInput.TextChanged+=(s,e)=>RefreshSummary();settings.Controls.Add(patternInput);
  settings.Controls.Add(TextLabel("填写编号：0–319 / 1000–1199",355,582,420,24,9,false));
  patternInfo.SetBounds(22,619,775,55);settings.Controls.Add(patternInfo);
  var footer=new TableLayoutPanel{Dock=DockStyle.Bottom,Height=175,Padding=new Padding(28,8,28,12),ColumnCount=2,RowCount=3};
  footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));footer.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,128));
  footer.RowStyles.Add(new RowStyle(SizeType.Absolute,62));footer.RowStyles.Add(new RowStyle(SizeType.Absolute,40));footer.RowStyles.Add(new RowStyle(SizeType.Percent,100));
  Controls.Add(footer);
  summary.Dock=DockStyle.Fill;summary.ForeColor=Color.FromArgb(39,77,124);footer.Controls.Add(summary,0,0);footer.SetColumnSpan(summary,2);
  outputLabel.Dock=DockStyle.Fill;outputLabel.TextAlign=ContentAlignment.MiddleLeft;outputLabel.AutoEllipsis=true;outputLabel.Text="输出："+output;footer.Controls.Add(outputLabel,0,1);
  Button browse=ActionButton("另存位置",0,0,116);browse.Dock=DockStyle.Fill;browse.Margin=new Padding(4);browse.Click+=(s,e)=>ChooseOutput();footer.Controls.Add(browse,1,1);
  var actions=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=3,RowCount=1,Margin=Padding.Empty};
  actions.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,145));actions.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));actions.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,165));footer.Controls.Add(actions,0,2);footer.SetColumnSpan(actions,2);
  Button reset=ActionButton("恢复默认选项",0,0,140);reset.Dock=DockStyle.Fill;reset.Click+=(s,e)=>{if(busy)return;fixedPattern.Checked=false;patternInput.Clear();foreach(var c in bosses)c.Checked=false;everdark.Checked=false;foreach(var c in terrainChecks)c.Checked=false;weighting.SelectedIndex=0;};actions.Controls.Add(reset,0,0);
  generate.Text="确定并生成";generate.Dock=DockStyle.Fill;generate.BackColor=Color.FromArgb(39,77,124);generate.ForeColor=Color.White;generate.FlatStyle=FlatStyle.Flat;generate.Click+=async(s,e)=>await Generate();actions.Controls.Add(generate,2,0);
  status.Dock=DockStyle.Fill;status.TextAlign=ContentAlignment.MiddleLeft;status.Text="原始基准：Steam 副本 · 1.03.5";actions.Controls.Add(status,1,0);
  FormClosing+=(s,e)=>{if(busy){e.Cancel=true;status.Text="正在生成，请等待完成后再关闭。";}};
  RefreshSummary();
 }
 void ChooseOutput(){if(busy)return;using(var d=new SaveFileDialog{Title="选择模组参数输出位置",Filter="参数文件|regulation.bin",FileName="regulation.bin",InitialDirectory=Path.GetDirectoryName(output),OverwritePrompt=false}){if(d.ShowDialog(this)==DialogResult.OK){output=d.FileName;outputLabel.Text="输出："+output;}}}
 Pattern CurrentPattern(){int id;return Int32.TryParse(patternInput.Text.Trim(),out id)&&patterns.ContainsKey(id)?patterns[id]:null;}
 void RefreshSummary(){
  if(bosses.Any(c=>c==null)||terrainChecks.Any(c=>c==null))return;
  var selected=Enumerable.Range(0,10).Where(i=>bosses[i].Checked).ToArray();
  var effective=(selected.Length==0?Enumerable.Range(0,10):selected.AsEnumerable()).Where(i=>!everdark.Checked || (i!=7 && i!=9)).ToArray();
  weighting.Enabled=selected.Length>1;
  for(int i=0;i<10;i++)bosses[i].ForeColor=everdark.Checked&&(i==7||i==9)?Color.Gray:Color.FromArgb(35,44,59);
  string pool=selected.Length==0?"原版夜王池":"已选 "+selected.Length+" 类夜王";
  string mode=everdark.Checked?"仅永夜（有效 "+effective.Length+" 类）":"普通 / 永夜按原版深度权重";
  summary.Text=pool+"  ·  "+mode+"\n地形："+(terrainChecks.All(c=>!c.Checked)?terrains[0]:String.Join("、",Enumerable.Range(0,5).Where(i=>terrainChecks[i].Checked).Select(i=>terrains[i+1].Split('·')[0].Trim())));
  var pat=CurrentPattern();
  patternInput.Enabled=fixedPattern.Checked;
  foreach(var c in bosses)c.Enabled=!fixedPattern.Checked;
  foreach(var c in terrainChecks)c.Enabled=!fixedPattern.Checked;
  weighting.Enabled=!fixedPattern.Checked&&selected.Length>1;
  patternInfo.Text=!fixedPattern.Checked?"生成后启动无缝联机，在圆桌厅打开房主控制器并应用。房主单独锁定的联机同步仍待验证。":pat==null?"请输入有效编号。网站结果链接可用于核对编号；不要填写 expedition seed。":"模板 "+pat.Id+" · "+names[pat.Boss]+" · "+(pat.Terrain==0?"普通地形":terrains[pat.Terrain])+"\n自动选择对应夜王 / 地形；只锁实际模板编号，首圈和掉落不固定。";
  if(fixedPattern.Checked){
   effective=pat==null?new int[0]:everdark.Checked&&(pat.Boss==7||pat.Boss==9)?new int[0]:new int[]{pat.Boss};
   summary.Text=pat==null?"房主锁定：请输入有效模板编号。":"房主锁定目标："+pat.Id+" · "+names[pat.Boss]+"\n地形："+(pat.Terrain==0?"普通地形":terrains[pat.Terrain])+" · "+(everdark.Checked?"仅永夜":"普通 / 永夜按原版权重");
  }
  generate.Enabled=!busy&&effective.Length>0;
  if(effective.Length==0&&(!fixedPattern.Checked||pat!=null))summary.Text="没有可用夜王：所选目标没有独立永夜版本，请调整选项。";
 }
 async Task Generate(){
  busy=true;settings.Enabled=false;generate.Enabled=false;progress.Visible=true;status.Text="正在生成并校验参数…";
  string token=Guid.NewGuid().ToString("N"), request=Path.Combine(dataHome,"requests",token+".json");
  string chosenOutput=output;
  try{
   Directory.CreateDirectory(Path.GetDirectoryName(request));
   var pat=fixedPattern.Checked?CurrentPattern():null;
   var data=new {PatternId=pat==null?(int?)null:pat.Id,Bosses=pat!=null?new int[]{pat.Boss}:Enumerable.Range(0,10).Where(i=>bosses[i].Checked).ToArray(),Everdark=everdark.Checked,Terrains=pat!=null?new int[0]:Enumerable.Range(0,5).Where(i=>terrainChecks[i].Checked).Select(i=>i+1).ToArray(),Weighting=weighting.SelectedIndex==0?"equal":"original",Output=chosenOutput};
   File.WriteAllText(request,json.Serialize(data),new UTF8Encoding(false));
   string response=await Task.Run(()=>{
    var si=new ProcessStartInfo{FileName=(string)config["PowerShell"],Arguments="-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \""+Path.Combine(home,"Generate.ps1")+"\" -Request \""+request+"\"",UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true,StandardOutputEncoding=Encoding.UTF8,StandardErrorEncoding=Encoding.UTF8,WorkingDirectory=home};
    using(var p=Process.Start(si)){
     var std=p.StandardOutput.ReadToEndAsync();var err=p.StandardError.ReadToEndAsync();
     p.WaitForExit();Task.WaitAll(std,err);
     if(p.ExitCode!=0)throw new Exception(String.IsNullOrWhiteSpace(err.Result)?std.Result:err.Result);
     return std.Result;
    }
   });
   var result=json.Deserialize<Dictionary<string,object>>(response.Trim());
   status.Text="生成完成 · 已验证 "+result["ChangedFields"]+" 处修改";
   MessageBox.Show(this,"已生成并校验：\n"+chosenOutput+"\n\n"+(result["Backup"]==null?"此前没有文件，无需备份。":"旧文件已备份为：\n"+result["Backup"])+"\n\n下次使用外部加载启动器开始新的远征。"+(pat==null?"":"\n请进入圆桌厅，打开房主控制器并应用；尚需队友联机验证。"), "生成完成",MessageBoxButtons.OK,MessageBoxIcon.Information);
  }catch(Exception ex){status.Text="生成未完成，请查看具体错误。";MessageBox.Show(this,ex.Message,"无法生成",MessageBoxButtons.OK,MessageBoxIcon.Error);}
  finally{busy=false;settings.Enabled=true;progress.Visible=false;RefreshSummary();}
 }
}
