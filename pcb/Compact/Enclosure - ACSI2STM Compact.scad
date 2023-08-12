$logo=true; // Is the ACSI2STM logo present ?
$db19=true; // Is the DB19 present ?
$idc20=false; // Is the IDC20 socket present ?
$idc20p=false; // Is the IDC20 piggyback present ?

$fn=100;
$f=0.41; // Floor height
$outwall=0.40; // Outer wall width
$inwall=0.79; // Inner wall width
$nutin=4.0; // Inner nut diameter
$nutout=4.6; // Outer nut diameter
$nuth=2.65; // Nut height
$nuthold=5.65; // Hut holder width
$screw=2; // Screw diameter
$screwhead=4.5; // Screw head diameter
$screwhead_h=1; // Screw head height
$back_height=4.5; // Total back side height
$front_height=5.6; // Total front side height
$pcbh=1.65; // PCB height

e=0.01; // Epsilon
screwhole=$screw+0.4; // Screw hole diameter
sd_height=2.4;

module pcb_poly(off=0) {
polygon([
  [0-off,0-off],
  [0-off,41.0+off/2],
  [2.8-off,43.8+off/2],
  [2.8-off,58.8+off],
  [8.2-off,64.3+off],

  [43.0+off,64.3+off],
  [48.5+off,58.8+off],
  [48.5+off,43.8+off/2],
  [51.3+off,41.0+off/2],
  [51.3+off,0-off],

  [47.3-off/4,0-off],
  [43.4-off/4,2.2-off],
  [40.4+off/4,2.2-off],
  [36.7+off/4,0-off],

  [30.8-off/4,0-off],
  [26.9-off/4,2.2-off],
  [23.9+off/4,2.2-off],
  [20.2+off/4,0-off],

  [14.3-off/4,0-off],
  [10.4-off/4,2.2-off],
  [7.4+off/4,2.2-off],
  [3.7+off/4,0-off],
]);
}

module nut_holder() {
  sz=$nutin+$inwall*2;
  translate([-$nuthold/2,-sz/2,0])
    difference() {
      cube([$nuthold,sz,$back_height-$pcbh]);
      translate([-e,$inwall,$back_height-$pcbh-$f-$nuth])
        cube([$nuthold+e*2,$nutin,$nuth]);
      translate([$nuthold/2-screwhole/2,$inwall+0.3,$back_height-$pcbh-$f-e])
        cube([screwhole,$nutin-0.6,$f+e*2]);
    }
}

module back_side() {
  difference() {
    translate([0,0,-$f])
      linear_extrude($back_height+$f)
        pcb_poly($outwall);
 
    linear_extrude($back_height+e)
      pcb_poly(-$inwall);
 
    translate([0,0,$back_height-$pcbh])
      linear_extrude($pcbh+e)
        pcb_poly();
 
    if($db19) {
      hull() {
        translate([6.0,50.9,-$f-e]) cylinder(h=$f+$back_height+2*e,d=6);
        translate([6.0-12,50.9,-$f-e]) cylinder(h=$f+$back_height+2*e,d=6);
      }
      hull() {
        translate([45.0,50.9,-$f-e]) cylinder(h=$f+$back_height+2*e,d=6);
        translate([45.0+12,50.9,-$f-e]) cylinder(h=$f+$back_height+2*e,d=6);
      }
    }

    if($idc20)
      translate([9.1,53.9,-$f-e])
        cube([33.1,9.4,$f+2*e]);

    if($logo)
      translate([51.3/2,10,-$f-e])
        scale([1,-1,1])
          linear_extrude($f/2+2*e)
            text("ACSI2STM", size=6, halign="center");
  }

  translate([3.6,16.1,0]) nut_holder();
  translate([3.6,39.5,0]) nut_holder();
  translate([6.3,57.3,0]) nut_holder();
  translate([45.0,57.3,0]) nut_holder();
  translate([47.8,39.5,0]) nut_holder();
  translate([47.8,16.1,0]) nut_holder();
}

module screw_pit() {
  difference() {
    cone=$screwhead-screwhole;
    translate([0,0,0]) {
      cylinder(h=$screwhead_h+$inwall,d=$screwhead+$inwall*2);
      translate([0,0,$screwhead_h+$inwall])
      cylinder(h=$front_height-($screwhead_h+$inwall),d1=$screwhead+$inwall*2,d2=screwhole+$inwall*2);
      translate([0,-screwhole/2-$inwall,0])
        cube([$screwhead/2+$inwall,screwhole+$inwall*2,$front_height]);
    }
    
    translate([0,0,-e])
       cylinder(h=$screwhead_h+e*2,d=$screwhead);
    translate([0,0,$screwhead_h-e])
       cylinder(h=cone+e*2,d2=screwhole,d1=$screwhead);
    translate([0,0,$screwhead_h+cone-e])
       cylinder(h=$front_height-(cone+$screwhead_h)+e*2,d=screwhole);
  }
}

module front_side() {
  difference() {
    translate([0,0,-$f])
      linear_extrude($front_height+$f)
        pcb_poly($outwall);
    
    translate([0,0,0])
      linear_extrude($front_height+e)
        pcb_poly(-$inwall);

    if($db19) {
      translate([6.0,50.9,-$f-e]) cylinder(h=$f+$front_height+2*e,d=5.6);
      translate([45.0,50.9,-$f-e]) cylinder(h=$f+$front_height+2*e,d=5.6);
      translate([10.0,46.0,-$f-e])
        linear_extrude($f+2*e)
          polygon([
            [0.0,0.0],
            [31.0,0.0],
            [27.0,8.8],
            [4.0,8.8]
          ]);
    }
    
    if($idc20p)
      translate([9.6,52.9,-$f-e])
        cube([32.1,7.4,$f+2*e]);

    // USB port
    translate([51.3-$inwall-e,19.0,$front_height-3.6])
      cube([$inwall+$outwall+2*e,9.4,3.6+e]);

    // Screw holes
    translate([3.6,16.1,-$f-e]) cylinder(h=$f+2*e, d=$screwhead);
    translate([3.6,39.5,-$f-e]) cylinder(h=$f+2*e, d=$screwhead);
    translate([6.3,57.3,-$f-e]) cylinder(h=$f+2*e, d=$screwhead);
    translate([45.0,57.3,-$f-e]) cylinder(h=$f+2*e, d=$screwhead);
    translate([47.8,39.5,-$f-e]) cylinder(h=$f+2*e, d=$screwhead);
    translate([47.8,16.1,-$f-e]) cylinder(h=$f+2*e, d=$screwhead);
    
    // MicroSD slots
    translate([1.9,-$outwall-e, $front_height
-sd_height])
      cube([47.5,$outwall+3+2*e,sd_height+e]);
  }

  translate([3.6,16.1,0]) rotate([0,0,180]) screw_pit();
  translate([3.6,39.5,0]) rotate([0,0,180]) screw_pit();
  translate([6.3,57.3,0]) rotate([0,0,180]) screw_pit();
  translate([45.0,57.3,0]) screw_pit();
  translate([47.8,39.5,0]) screw_pit();
  translate([47.8,16.1,0]) screw_pit();
    
}

translate([-55,0,0]) back_side();

front_side();