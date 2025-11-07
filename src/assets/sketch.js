var rotatevalue;
var arrow;
var Names = [];
var Sectors = [];
let Input;
let Name
let Started;
let Winner;
let File;
let size;


function preload() {
  soundFormats('mp3', 'ogg');
  tada = loadSound('tada.mp3');
}

function setup() {
  Input = createInput('Idea');
  Name = createInput('Name');
  let button = createButton('ADD');
  let remove = createButton('REMOVE');
  let start = createButton('START');
  let reset = createButton('RESET');
  let save = createButton('SAVE');
  size = Math.min(windowWidth,windowHeight) -21;
  File = createFileInput(handleFile);
  winner = false;
  createCanvas(size,size);
  handleFile(true);
  arrow = new Arrow();
  rotatevalue = random(0.1,0.3);
  button.mousePressed(AddName);
  remove.mousePressed(RemoveName);
  reset.mousePressed(ResetArrow);
  start.mousePressed(StartSpinner);
  save.mousePressed(DownloadSectors);
}

function draw() {
if(Sectors.length != 0)
{
  for(var i = 0;i < Sectors.length;i++)
  {
     Sectors[i].Draw((i)*(2*PI/Sectors.length),(i+1)*(2*PI/Sectors.length));
  }
} else clear();
  
if(Started)
{  
  if(!arrow.IsStopped())
    {
      if(rotatevalue > 0.0005 || rotatevalue < -0.0005)
      {
        rotatevalue *= 0.995;
      }
      else rotatevalue = 0;
      
    arrow.Update(rotatevalue);
    arrow.Show();
    }
  else
  {
    if(!winner)
    {
    arrow.Show();
      for(var j = 0;j < Sectors.length;j++)
      { 
        arrow.SelectWinner(Sectors[j]);
      }
    } 
    else
    {
      var wText = winner.Name + ' won!';
      arrow.Show();
      fill(0,0,0);
      strokeWeight(6)
      stroke(255,255,255);
      textSize((size*1.7) / (wText.length));
      textAlign(CENTER, CENTER);
      text(wText, width/2, height/3);
      strokeWeight(2)
      textSize(width*0.08);
      text(winner.Idea, 0, height/3,width,height);
      noStroke();
    }
  }
}
else arrow.Show();
}
function Sector(Color,Name,Idea)
{
   this.xPos = width/2;
   this.yPos = height/2;
   this.xSize = width -2;
   this.ySize = height-2;
   this.Color = Color;  
   this.Name = Name;
   this.Idea = Idea;
   this.Angle1 = 0;
   this.Angle2 = 0;
   this.DeltaAngle = 0;
  
  this.Draw = function(Angle1,Angle2)
  {  this.Angle1 = Angle1;
     this.Angle2 = Angle2;
     this.DeltaAngle = (this.Angle1 + this.Angle2) / 2;
     fill(this.Color);
     arc(this.xPos,this.yPos,this.xSize,this.ySize,this.Angle1,this.Angle2,PIE);
     
     fill(0);
     push();
     translate((cos(this.DeltaAngle)*(width*0.30))+(width*0.50),(sin(this.DeltaAngle)*(height*0.30))+(height*0.50));
     textSize(((size + max(this.xSize,this.ySize))*0.4)/(this.Name.length + Sectors.length));
     textAlign(CENTER, CENTER);
     stroke(255,255,255);
     strokeWeight(4)
     text(this.Name, 0, 0);
     noStroke();
     pop();
  }
}

function Arrow()
{
  this.xPos = width  / 2;
  this.yPos = height / 2;
  this.rad = random(0,2*PI);
  this.Stopped = false;
  
  this.Update = function(value)
  {  
    if(value == 0)
      this.Stopped = true;
      this.rad += value; 
  }
  this.Show = function()
  {
     var avgHeightWidth = ((height + width)/2);
     push(); 
     translate(width/2,height/2);
     rotate(this.rad); 
     noStroke();
     fill(255,255,0);
     rectMode(CENTER);
     triangle(avgHeightWidth / 4,avgHeightWidth*0.125,avgHeightWidth / 4,-avgHeightWidth*0.125,avgHeightWidth / 2.3,0);
     rect(0,0,(avgHeightWidth*0.68),(avgHeightWidth*0.125))
     pop(); 
  }
  this.IsStopped = function()
  {
    return this.Stopped;
  }
  this.GetRad = function()
  {
    return this.rad; 
  }
  this.SelectWinner = function(Sector)
  {
    if(this.rad%TAU >= Sector.Angle1 && this.rad%TAU <= Sector.Angle2)
    {
      tada.play();
      winner = { Name: Sector.Name, Idea: Sector.Idea};
    }
  }
}

function AddName()
{
  if((Input.value()).length != 0)
        Sectors.push(new Sector((color(random(0,255),random(0,255),random(0,255))),Name.value(),Input.value()));
  Input.value('');
  Name.value('');
  localStorage.setItem('Sectors',JSON.stringify(Sectors));
}
function RemoveName()
{
    Sectors.pop();
    localStorage.setItem('Sectors',JSON.stringify(Sectors));
}
function StartSpinner()
{
  Started = true;
}
function keyReleased() {
  if (keyCode === ENTER) 
  {
    AddName();
  }
}
function ResetArrow()
{
  Started = false;
  winner = false;
  rotatevalue = random(0.1,0.3);
  arrow = new Arrow();
}
function DownloadSectors()
{
 localStorage.setItem('Sectors',JSON.stringify(Sectors));
 download(JSON.stringify(Sectors),'ideas') 
}

function download(data, filename) 
{
    var file = new Blob([data], {type: "text"});
    if (window.navigator.msSaveOrOpenBlob) // IE10+
        window.navigator.msSaveOrOpenBlob(file, filename);
    else 
    { // Others
        var a = document.createElement("a"),
                url = URL.createObjectURL(file);
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        setTimeout(function() 
        {
            document.body.removeChild(a);
            window.URL.revokeObjectURL(url);  
        }, 0); 
    }
}

function handleFile(file) {
  var parsedJSON;
  Sectors = [];
  if (file.type === 'text') 
  {   
     parsedJSON = JSON.parse(file.data)  ;   
  }
  else 
  {
    parsedJSON = JSON.parse(localStorage.getItem('Sectors'));
  }
  try 
  {
     for (var i=0;i<parsedJSON.length;i++) 
     {
       Sectors.push(new Sector(color(parsedJSON[i].Color.levels),parsedJSON[i].Name,parsedJSON[i].Idea));
     } 
  }
  catch 
  {
    
  }
  localStorage.setItem('Sectors',JSON.stringify(Sectors));
  File.value('');
}
function windowResized() 
{
  size = Math.min(windowWidth, windowHeight) -21;
  resizeCanvas(size,size);
  clear();
  for(var i = 0;i < Sectors.length;i++)
  {
     Sectors[i].xPos = width/2;
     Sectors[i].yPos = height/2;
     Sectors[i].xSize = width -2;
     Sectors[i].ySize = height -2;
  }
}