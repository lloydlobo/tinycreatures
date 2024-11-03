// Originally from moonshine fog shader

extern vec3 fog_color=vec3(.35,.48,.95);
extern int octaves=4;
extern vec2 speed=vec2(0.,1.);
extern float time;

float rand(vec2 coord)
{
    return fract(sin(dot(coord,vec2(56,78))*1000.)*1000.);
}

float noise(vec2 coord)
{
    vec2 i=floor(coord);//get the whole number
    vec2 f=fract(coord);//get the fraction number
    float a=rand(i);//top-left
    float b=rand(i+vec2(1.,0.));//top-right
    float c=rand(i+vec2(0.,1.));//bottom-left
    float d=rand(i+vec2(1.,1.));//bottom-right
    vec2 cubic=f*f*(3.-2.*f);
    return mix(a,b,cubic.x)+(c-a)*cubic.y*(1.-cubic.x)+(d-b)*cubic.x*cubic.y;//interpolate
}

float fbm(vec2 coord)//fractal brownian motion
{
    float value=0.;
    float scale=.5;
    for(int i=0;i<octaves;i++)
    {
        value+=noise(coord)*scale;
        coord*=2.;
        scale*=.5;
    }
    return value;
}

vec4 effect(vec4 color,Image texture,vec2 tc,vec2 sc)
{
    float f=20.;
    vec2 coord=tc*f*.5;
    vec2 motion=vec2(0.);
    float final=0.;

    for(int i=-1;i<=1;i++)
    {
        float dy=-i;
        float dx=i;
        vec2 disp=vec2(dx*time*speed.x,dy*time*speed.y);

        motion+=vec2(fbm(coord+disp));
        final+=fbm(coord+motion);
    }
    return vec4(fog_color,final*.5);
}

// --[[
        // Animated 2D Fog (procedural)
        // Originally for Godot Engine by Gonkee https://www.youtube.com/watch?v=QEaTsz_0o44&t=6s

        // Translated for löve by Brandon Blanker Lim-it @flamendless
    // ]]--

    // --[[
            // SAMPLE USAGE:
            // local moonshine = require("moonshine")
            // local effect

            // local image, bg
            // local image_data
            // local shader_fog
            // local time = 0

            // function love.load()
            // 	image_data = love.image.newImageData(love.graphics.getWidth(), love.graphics.getHeight())
            // 	image = love.graphics.newImage(image_data)
            // 	bg = love.graphics.newImage("bg.png")
            // 	effect = moonshine(moonshine.effects.fog)
            // 	effect.fog.fog_color = {0.1, 0.0, 0.0}
            // 	effect.fog.speed = {0.2, 0.9}
            // end

            // function love.update(dt)
            // 	time = time + dt
            // 	effect.fog.time = time
            // end

            // function love.draw()
            // 	love.graphics.draw(bg)
            // 	effect(function()
            // 		love.graphics.draw(image)
        // 	end)
        // end
    // ]]
