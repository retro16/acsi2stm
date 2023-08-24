// Add the ACSI2STM logo
$logo=true;

// Add DB19 connector
$db19=true;

// Add IDC20 Satan port socket
$idc20=false;

// Add IDC20 piggyback. Incompatible with DB19.
$idc20p=false;

// Floor height
$f=0.41;

// Outer wall width
$outwall=0.79;

// Inner wall width
$inwall=0.79;

// Screw diameter
$screw=2;

// Tapped screw hole diameter offset (positive = bigger)
$tap_hole_offset=0;

// Screw head diameter
$screwhead=5;

// Screw head height
$screwhead_h=1;

// Total back side height
$back_height=5.6;

// Total front side height
$front_height=5.6;

// PCB height
$pcbh=1.65;

/* [Hidden] */

$fn=100;
e=0.01; // Epsilon
screwhole=$screw+0.4; // Screw hole diameter
taphole=$screw+$tap_hole_offset; // Tapped screw hole diameter
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

module tapped_hole() {
  difference() {
    translate([0,0,0]) {
      cylinder(h=$back_height-$pcbh,d=$screwhead);
      translate([0,-$screwhead/2,0])
        cube([$screwhead/2+$inwall,$screwhead,$back_height-$pcbh]);
    }
    
    cylinder(h=$back_height-$pcbh+e,d=taphole);
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
      translate([6.0,50.9,-$f-e]) cylinder(h=$f+$back_height+2*e,d=7.5);
      translate([6.0-12,50.9-3,-$f-e]) cube([12,6,2*e+$f+$back_height]);
      translate([45.0,50.9,-$f-e]) cylinder(h=$f+$back_height+2*e,d=7.5);
      translate([45.0,50.9-3,-$f-e]) cube([12,6,2*e+$f+$back_height]);
    }

    if($idc20)
      translate([9.1,53.9,-$f-e])
        cube([33.1,9.4,$f+2*e]);

    if($logo)
      translate([51.3/2,12,-$f-e])
        scale([1,-1,1])
          linear_extrude($f/2+2*e)
            text("ACSI2STM", size=7, spacing=0.85, halign="center");
  }

  translate([3.6,16.1,0]) rotate([0,0,180]) tapped_hole();
  translate([3.6,39.5,0]) rotate([0,0,180]) tapped_hole();
  translate([6.3,57.3,0]) rotate([0,0,180]) tapped_hole();
  translate([45.0,57.3,0]) tapped_hole();
  translate([47.7,39.5,0]) tapped_hole();
  translate([47.7,16.1,0]) tapped_hole();
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
      translate([2.8,47.0,-$f-e])
        linear_extrude($f+2*e)
          polygon([
            [$inwall,0],
            [$inwall,6.5],
            [$inwall+4,6.5],
            [$inwall+7,9],
            [45.7-$inwall-7,9],
            [45.7-$inwall-4,6.5],
            [45.7-$inwall,6.5],
            [45.7-$inwall,0],
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
    translate([47.7,39.5,-$f-e]) cylinder(h=$f+2*e, d=$screwhead);
    translate([47.7,16.1,-$f-e]) cylinder(h=$f+2*e, d=$screwhead);
    
    // MicroSD slots
    translate([1.9,-$outwall-e, $front_height
-sd_height])
      cube([47.5,$outwall+3+2*e,sd_height+e]);
  }

  translate([3.6,16.1,0]) rotate([0,0,180]) screw_pit();
  translate([3.6,39.5,0]) rotate([0,0,180]) screw_pit();
  translate([6.3,57.3,0]) rotate([0,0,180]) screw_pit();
  translate([45.0,57.3,0]) screw_pit();
  translate([47.7,39.5,0]) screw_pit();
  translate([47.7,16.1,0]) screw_pit();
    
}

translate([-55,0,0]) back_side();

front_side();
