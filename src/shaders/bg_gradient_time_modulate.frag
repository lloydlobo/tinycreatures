extern vec2 screen;
extern float time;//> love.timer.getTime()

// See also http://dev.thi.ng/gradients/
// green-cyan [[0.000 0.500 0.500] [0.000 0.500 0.500] [0.000 0.333 0.500] [0.000 0.667 0.500]]
vec3 palette(float t){
     vec3 a=vec3(0.,.5,.5);
     vec3 b=vec3(0.,.5,.5);
     vec3 c=vec3(.0,.333,.5);
     vec3 d=vec3(.0,.6667,.500);
     
     return a+b*cos(6.28318*(c*t+d));
}

// Copied from [SkyVaultGames ─ Love2D | Shader Tutorial 1 | Introduction](https://www.youtube.com/watch?v=DOyJemh_7HE&t=1s)
vec4 effect(vec4 color,Image image,vec2 uvs,vec2 screen_coords){
     vec4 pixel=Texel(image,uvs);
     
     float aspect_ratio=screen.x/screen.y;
     
     // Normalize screen coordinates
     vec2 sc=vec2(screen_coords.x/screen.x,screen_coords.y/screen.y);
     
     // glsl idiom for uv (screen)─not uvs (texture)
     vec2 uv=vec2(sc.x/aspect_ratio,sc.y);
     
     vec2 uv0=uv;// original normalized screen
     
     // Radial distance from canvas center
     float d=-exp(length(uv));d=abs(d);
     
     // Modulate color channels over time
     float f=1.;
     
     vec3 col=vec3(0.);
     vec3 final_col=vec3(0.);
     
     float t=.0625*time;
     
     // Debug simulation time
     // t*=.5;
     t*=2.;
     float f_smooth_d=.25;
     
     float f_invert_speed_density=8.;
     
     for(float i=1.;i<4.;++i){
          // f=.5-.5*sin((uv[0]*3.14159+time*.0625))*i;/*f/=i;*/
          
          float width=1.;
          
          // #1 Fade to night
          // width/=clamp(pow(d,4)*pow(i,4),-32,32);
          
          f=.5-.5*sin(width*uv[0]*3.14159+t)*i;/*f/=i;*/
          
          // Color this iteration
          col=vec3(d,uv[0]-f,uv[1]-f);col/=i;
          
          // Accentuate darker contrast
          d=pow(d,1.2);d=abs(d);
          
          // Seed from cosine gradient generator palette
          col.r/=mix(palette(t).r,col.r,clamp((sin(t/d)/8)/i,.382,1.));
          
          col.gb+=.125*mix(palette(i*(-t)).gb,col.gb,clamp(f/i,.382,.618));
          
          // Inverted gradient across screen
          col.r*=pow(f/i,f_invert_speed_density*sin(t*pow(.5*d,f_smooth_d)));
          
          // #2 Fade to night
          // col*=f/pow(i,.5);
          
          // Feather radient edges
          col.gb*=clamp(1.-sin(uvs/d)/i,.1,.8);col.gb*=col.gb/d;
          
          final_col+=col;
     }
     
     // Darken
     // final_col*=.8;
     
     return pixel*vec4(final_col,1.);// red-pink-yellow
}

// Archived on 20241102
//  extern vec2 screen;
//  extern float time;//> love.timer.getTime()
//
//  vec4 effect(vec4 color,Image image,vec2 uvs,vec2 screen_coords){
     //       vec4 pixel=Texel(image,uvs);
     //
     //       // Normalize screen coordinates
     //       vec2 sc=vec2(screen_coords.x/screen.x,screen_coords.y/screen.y);
     //
     //       vec3 col=vec3(1.);
     //
     //       // Modulate color channels over time
     //       float f=.5-.5*sin((sc[0]*3.14159+time/5.));
     //
     //       // Radial distance from canvas center
     //       float d=length(sc);
     //
     //       col[1]=sc[0]-f;// static based on x position
     //       col[2]=sc[1]-f;// static based on y position
     //
     //       d=pow(d,1.2);
     //       col.yz*=col.yz/d;
     //
     //       return pixel*vec4(col,1.);// red-pink-yellow
//  }
