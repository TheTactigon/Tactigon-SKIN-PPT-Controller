import processing.serial.*;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.awt.*;
import java.awt.event.*;
import java.awt.MouseInfo;
import java.awt.Point;
import java.awt.Robot;
import java.awt.event.KeyEvent;
import java.awt.event.InputEvent;
import controlP5.*;
import java.util.*;

//button array def
private final String VERSION = "1.0";
private final int BUTTON_2 = 0;
private final int BUTTON_3 = 1;
private final int BUTTON_4 = 2;

private Robot r;           //Control mouse and keyboard
private Serial myPort;    // The serial port:
private int eol = 0x0A;      // ASCII linefeed

//Current Data
private float roll;
private float pitch;
private float yaw;

//Offset Values
private float rollZero;
private float pitchZero;
private float yawZero;

//Zero Button
private int zeroX = 200;
private int zeroY = 50;
private int lenX = 80;
private int lenY = 30;

//Reset Button
private int resetX = 200;
private int resetY = 90;

//Connect Button
private int connectX = 200;
private int connectY = 170;

//HELP Button
private int helpX = 200;
private int helpY = 210;

//Power Pi button
private int powerpiX = 200;
private int powerpiY = 250;

//Mode Button
private int modeX = 200;
private int modeY = 170;

//State variables
private boolean doingZero = false;
private boolean offsetsCalculated = false;
private boolean powerpi = false;
private boolean controlEnabled = false;
private boolean newValues = false;
private boolean ppMode = true;

//private boolean mouseButtonPressed = false;
private boolean connected = false;
private boolean filter = true;
CheckBox checkboxStay;
private boolean doClickStay = true;
private boolean zoom = false;
private boolean zoomed = false;

//Dynamic parameters
private float alpha = 0.80; //IIR filter alpha

//UI Strings
private String offsetsString = "";
private String buttonsString = "";
private int[] buttons = new int[3];
private int debounce = 100;
private int leftClickTime = 0;
private int[] lastPressed = new int[] {0, 0, 0};
private int currentCOM = 0;
private int eventCnt = 0;
int scrollDistance = 1;
ControlP5 comboPort;
private int gPpmodeStat = 0;

private PImage logo;
private PImage logoNext;
private int centerX = displayWidth/2, centerY = displayHeight/2;
private int circleX = centerX, circleY = centerY;
private int radius = 100;
private int startcenterX = centerX + radius, startcenterY = centerY;
private int startcircleX = circleX + radius, startcircleY = circleY;
private int step = 0, maxstep = 35;

private void addLogo() {
  logo = loadImage("TheTactigonTM.png");
  logoNext = loadImage("logo-bianco-next.png");
  //image(logo,218,120,50,50);
  image(logoNext, 15, 230, 90, 18);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
void setup()
{
  //Offsets
  rollZero = 0;
  pitchZero = 0;
  yawZero = 0;

  size(300, 300);

  println(Serial.list());
  println("Setup");
  frameRate(20);

  String[] portNames = Serial.list();
  comboPort = new ControlP5(this);
  comboPort.addScrollableList("Port")
    .setPosition(20, connectY + 5)
    .setSize(150, 200)
    .setBarHeight(20)
    .setItemHeight(20)
    .addItems(portNames)
    .setValue(0)
    ;
  try {
    r = new Robot();
  }
  catch (Exception e) {
    text("Problem while initializing application", 20, 110);
  }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
private void setupSerial(String portName)
{
  println("Setup: " + portName);
  myPort = new Serial(this, portName, 115200);
  myPort.bufferUntil(eol);
  connected = true;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
private void disposeSerial()
{
  //Close Serial Connection and Sets State
  println("Dispose");
  myPort.dispose();
  resetOffsets();
  connected = false;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
private void drawButtons()
{
  //GUI's buttons
  //containers
  fill(103);
  rect(zeroX - 5, zeroY - 5, (resetX - zeroX + lenX) + 10, (resetY - zeroY + lenY) + 10);
  //rect(modeX-5,modeY-5,(helpX-modeX+lenX)+10, (helpY-modeY+lenY)+10);
  rect(modeX - 5, modeY - 5, (powerpiX - modeX + lenX) + 10, (powerpiY - modeY + lenY) + 10);
  //zero button
  textAlign(CENTER, BOTTOM);
  fill(153);
  rect(zeroX, zeroY, lenX, lenY);
  if (offsetsCalculated) {
    fill(0, 255, 0);
  } else {
    fill(255, 0, 0);
  }
  text("Zero", 240, 70);

  //reset button
  fill(153);
  rect(resetX, resetY, lenX, lenY);
  fill(255);
  text("Reset", 240, 110);

  //connect button
  fill(153);
  rect(connectX, connectY, lenX, lenY);
  fill(255);
  String connectLabel = "";
  if (!connected) {
    connectLabel = "Connect";
  } else {
    connectLabel = "Disconnect";
  }
  text(connectLabel, 240, connectY + 20);

  //help button
  fill(153);
  rect(helpX, helpY, lenX, lenY);
  fill(255);
  text("HELP", 240, helpY + 20);

  //Power Pi button
  fill(153);
  rect(powerpiX, powerpiY, lenX, lenY);
  if (powerpi) {
    fill(255, 0, 0);
  } else {
    fill(0, 255, 0);
  }
  text("POWER", 240, powerpiY + 20);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
void draw()
{
  Point mouse;
  mouse = MouseInfo.getPointerInfo().getLocation();
  println( "X=" + mouse.x + " Y=" + mouse.y );
  //GUI
  background(0);

  //Title
  if (controlEnabled)
    fill(0, 255, 0);
  else
    fill(255, 0, 0);
  textSize(22);
  text("The Tactigon Experience", 20, 10);

  //buttons
  textSize(10);
  drawButtons();
  //Roll, Ptch lables
  textAlign(LEFT, TOP);
  fill(255, 255, 255);
  text("Roll: " + roll, 20, 50);
  text("Pitch: " + pitch, 20, 70);

  //info label
  textSize(16);
  if (connected == false)
  {
    offsetsString = "Please connect";
    fill(255, 0, 0);
  } else
  {
    if (offsetsCalculated == false)
    {
      offsetsString = "Please make ZERO";
      fill(255, 0, 0);
    } else
    {
      offsetsString = "Operating!";
      fill(0, 255, 0);
    }
  }
  text(offsetsString, 20, 97);

  //Motion handle
  if (controlEnabled && newValues)
  {
    newValues = false;
    ///////////////////////////////////////////////////////////////////////////////////
    //move handling
    if ((millis() > leftClickTime + 400) || (doClickStay == false))
    {
      if (ppMode)
      {
        int event = ppModeGestureStateMachine(roll);
        if (!zoom) {
          if (event == 1)
          {
            if (!zoomed) {
              println("prev slide");
              r.keyPress(KeyEvent.VK_LEFT);
              r.keyRelease(KeyEvent.VK_LEFT);
            } else {
              if (circleY > centerY - 310) {
                println("up in zoom");
                circleY -= 62;
                r.keyPress(KeyEvent.VK_UP);
                r.keyRelease(KeyEvent.VK_UP);
              }
            }
          } else if (event == 2)
          {
            if (!zoomed) {
              println("next slide");
              r.keyPress(KeyEvent.VK_RIGHT);
              r.keyRelease(KeyEvent.VK_RIGHT);
            } else {
              if (circleY < centerY + 310) {
                circleY += 62;
                r.keyPress(KeyEvent.VK_DOWN);
                r.keyRelease(KeyEvent.VK_DOWN);
              }
            }
          }
        }

        if (zoom) { //if zoom function is activated
          event = ppModeGestureStateMachine(pitch);
          if ((event == 1) && (zoomed == true)) {
            println("zoom out");
            r.keyPress(KeyEvent.VK_CONTROL);
            r.keyPress(KeyEvent.VK_MINUS);
            r.keyRelease(KeyEvent.VK_MINUS);
            r.keyPress(KeyEvent.VK_MINUS);
            r.keyRelease(KeyEvent.VK_MINUS);
            r.keyPress(KeyEvent.VK_MINUS);
            r.keyRelease(KeyEvent.VK_MINUS);
            r.keyRelease(KeyEvent.VK_CONTROL);
            println("zoom false");
            zoomed = false;
            zoom = false;
            //calculate compensation values for the coordinates
            //This is caused by a missmatch in real and calculated coordinates by the library
            startcircleX = (circleX + radius) - (153600/(circleX + radius));
            startcircleY =circleY - (48600/circleY);
            delay(500);
          } else if (event == 2) {
            println("zoom in");
            r.keyPress(KeyEvent.VK_CONTROL);
            r.keyPress(KeyEvent.VK_PLUS);
            r.keyRelease(KeyEvent.VK_PLUS);
            r.keyPress(KeyEvent.VK_PLUS);
            r.keyRelease(KeyEvent.VK_PLUS);
            r.keyPress(KeyEvent.VK_PLUS);
            r.keyRelease(KeyEvent.VK_PLUS);
            r.keyRelease(KeyEvent.VK_CONTROL);
            circleX = centerX;
            circleY = centerY;
            zoom = false;
            zoomed = true;
            delay(500);
          }
        } else if ((zoom == false) && (zoomed == true)) {
          event = ppModeGestureStateMachine(pitch);
          if (event == 1) {
            if (circleX > centerX - 615) {
              println("left in zoom");
              circleX -= 123;
              r.keyPress(KeyEvent.VK_LEFT);          
              r.keyRelease(KeyEvent.VK_LEFT);
            }
          } else if (event == 2) {
            if (circleX < centerX + 615) {
              println("right in zoom");
              circleX += 123;
              r.keyPress(KeyEvent.VK_RIGHT);          
              r.keyRelease(KeyEvent.VK_RIGHT);
            }
          }
        }
      }
    }

    ///////////////////////////////////////////////////////////////////////////////////
    //buttons handling

    for (int i = 0; i < buttons.length; i++)
    {
      if (millis() > lastPressed[i] + debounce)
      {
        lastPressed[i] = millis();
        if (buttons[i] == 0)
        {
          eventCnt++;
          println("event " + eventCnt);
          switch (i)
          {
          case BUTTON_4: //button 2
            println("zoom true");
            zoom = true;
            break;

          case BUTTON_3:
            if (!zoomed) {
              //laser tool
              mouse = MouseInfo.getPointerInfo().getLocation();
              r.mouseMove(startcircleX, startcircleY);
              r.keyPress(KeyEvent.VK_CONTROL);
              r.keyPress(KeyEvent.VK_L);
              r.keyRelease(KeyEvent.VK_L);
              r.keyRelease(KeyEvent.VK_CONTROL);
              for (step = 0; step < maxstep; step++) {
                float t = 2 * PI * step / maxstep;
                int X = (int)(circleX + radius * cos(t));
                int Y = (int)(circleY + radius * sin(t));
                r.mouseMove(X, Y);
                delay(35);
              }
              r.keyPress(KeyEvent.VK_CONTROL);
              r.keyPress(KeyEvent.VK_L);
              r.keyRelease(KeyEvent.VK_L);
              r.keyRelease(KeyEvent.VK_CONTROL);
              circleX = centerX;
              circleY = centerY;
              startcircleX = startcenterX;
              startcircleY = startcenterY;
              delay(500);
            }
            break;

          case BUTTON_2:
            if (!zoomed) {
              //pen tool
              mouse = MouseInfo.getPointerInfo().getLocation();
              r.mouseMove(startcircleX, startcircleY);
              r.keyPress(KeyEvent.VK_CONTROL);
              r.keyPress(KeyEvent.VK_P);
              r.keyRelease(KeyEvent.VK_P);
              r.keyRelease(KeyEvent.VK_CONTROL);
              r.mousePress(InputEvent.BUTTON1_DOWN_MASK);
              for (step = 0; step < maxstep; step++) { //number of points in the circle move
                float t = 2 * PI * step / maxstep;
                int X = (int)(circleX + radius * cos(t));
                int Y = (int)(circleY + radius * sin(t));
                r.mouseMove(X, Y);
                delay(35);
              }
              r.mouseRelease(InputEvent.BUTTON1_DOWN_MASK);
              r.keyPress(KeyEvent.VK_CONTROL);
              r.keyPress(KeyEvent.VK_P);
              r.keyRelease(KeyEvent.VK_P);
              r.keyRelease(KeyEvent.VK_CONTROL);
              circleX = centerX;
              circleY = centerY;
              startcircleX = startcenterX;
              startcircleY = startcenterY;
              delay(500);
            }
            break;

          default:
            break;
          }
        } else
        {
          //button off
          switch (i)
          {
          case BUTTON_2:
            break;

          case BUTTON_3:
            break;

          case BUTTON_4:
            break;
          }
        }
      }
    }
  }
  addLogo();
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
int ppModeGestureStateMachine(float r)
{
  int event = 0;

  if (gPpmodeStat == 0)
  {
    if (r > 30)
    {
      gPpmodeStat = 1;
      event = 1;
    } else if (r < -35)
    {
      gPpmodeStat = 1;
      event = 2;
    }
  } else
  {
    if (abs(r) < 35)
      gPpmodeStat = 0;
  }

  return event;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
void controlEvent(ControlEvent theEvent)
{
  // DropdownList is of type ControlGroup.
  // A controlEvent will be triggered from inside the ControlGroup class.
  // therefore you need to check the originator of the Event with
  // if (theEvent.isGroup())
  // to avoid an error message thrown by controlP5.

  if (theEvent.isGroup()) {
    // check if the Event was triggered from a ControlGroup
    println("event from group : " + theEvent.getGroup().getValue() + " from " + theEvent.getGroup());
  } else if (theEvent.isController()) {
    println("event from controller : " + theEvent.getController().getValue() + " from " + theEvent.getController());
  }

  //event from combo port
  if (theEvent.isFrom("Port")) {
    currentCOM = (int)theEvent.getValue();
    println("Current COM: " + currentCOM);
  }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
void openHelp()
{
  if (Desktop.isDesktopSupported()) {
    try {
      File myFile;

      myFile = new File("QuickStart.pdf");

      Desktop.getDesktop().open(myFile);
    }
    catch (IOException ex) {
      fill(255, 255, 255);
      text("ERROR", 20, 20);
      // no application registered for PDFs
    }
  }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
void powerPi()
{
  myPort.write("power");
  println("Power down command sent to the RPi");
  disposeSerial();
  powerpi = true;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
void mouseClicked()
{
  if (connected)
  {
    if (!doingZero)
    {
      if (mouseX > zeroX && mouseX < zeroX + lenX && mouseY > zeroY && mouseY < zeroY + lenY)
      {
        println("Bottone Zero");
        //Zero
        doingZero = true;
      }

      if (mouseX > resetX && mouseX < resetX + lenX && mouseY > resetY && mouseY < resetY + lenY)
      {
        println("Bottone Reset");
        //Zero
        resetOffsets();
      }
    }
  }
  if (mouseX > helpX && mouseX < helpX + lenX && mouseY > helpY + 10 && mouseY < helpY + lenY) {
    //HELP
    openHelp();
  }
  if (mouseX > powerpiX && mouseX < powerpiX + lenX && mouseY > powerpiY + 10 && mouseY < powerpiY + lenY) {
    //Power Pi
    powerPi();
  }
  if (mouseX > connectX && mouseX < connectX + lenX && mouseY > connectY && mouseY < connectY + lenY) {
    if (!connected) {
      setupSerial((String)comboPort.get(ScrollableList.class, "Port").getItem(currentCOM).get("text"));
    } else {
      disposeSerial();
    }
  }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
private void resetOffsets()
{
  rollZero = 0;
  pitchZero = 0;
  yawZero = 0;
  controlEnabled = false;
  offsetsCalculated = false;
  powerpi = false;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
private void calculateOffsets()
{
  resetOffsets();
  rollZero = roll;
  pitchZero = pitch;
  yawZero = yaw;
  offsetsCalculated = true;
  controlEnabled = true;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
private float getNormalized(float angle)
{
  float ret = 0.;

  if (angle > 90.) {
    ret = angle - 180.;
  } else if (angle < -90.) {
    ret = angle + 180.;
  } else {
    ret = angle;
  }
  return ret;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
private float iirFilter(float prevY, float x)
{
  float y, locAlpha;

  if (abs((prevY - x) / x) < 0.10)
    locAlpha = 0.97;
  else
    locAlpha = alpha;

  y = (1 - locAlpha) * x + locAlpha * prevY;
  return y;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
private void parseValues(String input)
{
  float prevRoll, prevPitch, prevYaw;

  prevRoll = roll;
  prevPitch = pitch;
  prevYaw = yaw;

  roll = getNormalized(((Float.parseFloat(input.split(" ")[0]) / 10) - 180) - rollZero);
  pitch = getNormalized(((Float.parseFloat(input.split(" ")[1]) / 10) - 180) - pitchZero);
  yaw = getNormalized(((Float.parseFloat(input.split(" ")[2]) / 10) - 180) - yawZero);
  buttonsString = input.split(" ")[3]; //her ewe get button state

  if (offsetsCalculated && filter) {
    roll = iirFilter(prevRoll, roll);
    pitch = iirFilter(prevPitch, pitch);
    yaw = iirFilter(prevYaw, yaw);
  }
  for (int i = 0; i < buttons.length; ) {
    buttons[i] = Integer.parseInt(buttonsString.substring(i, ++i));
  }
  newValues = true;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
public void serialEvent(Serial p)
{
  try {
    String input = p.readString();
    p.clear();
    // print(input);
    try {
      if (doingZero)
      {
        calculateOffsets();
        doingZero = false;
      }
      parseValues(input);
    }
    catch (Exception e) {
      println("Problems while reading data from The Tactigon", 20, 110);
    }
  }
  catch (Exception e) {
    text("Problems while reading data from Serial port", 20, 110);
    connected = false;
    setupSerial((String)comboPort.get(ScrollableList.class, "Port").getItem(0).get("text"));
  }
}
